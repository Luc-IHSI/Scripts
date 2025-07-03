#Requires -Version 5.1

<#
.SYNOPSIS
    Logs off user(s) specified. You can't log off a user from the console session.
.DESCRIPTION
    Logs off user(s) specified. You can't log off a user from the console session.
.EXAMPLE
     -User "Administrator"
    Logs off Administrator user.
.EXAMPLE
     -User "Administrator","Guest"
    Logs off Administrator and Guest users.
.EXAMPLE
    PS C:> Logoff-User.ps1 -User "Administrator","Guest"
    Logs off Administrator and Guest users.
.OUTPUTS
    String[]
.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Release Notes:
    Initial Release
By using this script, you indicate your acceptance of the following legal terms as well as our Terms of Use at https://www.ninjaone.com/terms-of-use.
    Ownership Rights: NinjaOne owns and will continue to own all right, title, and interest in and to the script (including the copyright). NinjaOne is giving you a limited license to use the script in accordance with these legal terms. 
    Use Limitation: You may only use the script for your legitimate personal or internal business purposes, and you may not share the script with another party. 
    Republication Prohibition: Under no circumstances are you permitted to re-publish the script in any script library or website belonging to or under the control of any other software provider. 
    Warranty Disclaimer: The script is provided “as is” and “as available”, without warranty of any kind. NinjaOne makes no promise or guarantee that the script will be free from defects or that it will meet your specific needs or expectations. 
    Assumption of Risk: Your use of the script is at your own risk. You acknowledge that there are certain inherent risks in using the script, and you understand and assume each of those risks. 
    Waiver and Release: You will not hold NinjaOne responsible for any adverse or unintended consequences resulting from your use of the script, and you waive any legal or equitable rights or remedies you may have against NinjaOne relating to your use of the script. 
    EULA: If you are a NinjaOne customer, your use of the script is subject to the End User License Agreement applicable to you (EULA).
.COMPONENT
    ManageUsers
#>

[CmdletBinding(SupportsShouldProcess = $True)]
param (
    # User name(s) to log off
    [Parameter(Mandatory = $true)]
    [String[]]
    $User
)

begin {
    function Test-IsElevated {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object System.Security.Principal.WindowsPrincipal($id)
        if ($p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator))
        { Write-Output $true }
        else
        { Write-Output $false }
    }
    Function Get-QueryUser() {
        Param()
        # Replaces all occurrences of 2 or more spaces in a row with a single comma
        $Lines = @(query.exe user).foreach({ $(($_) -replace ('s{2,}', ',')) })
        $Header = $($Lines[0].split(',').trim())
        for ($i = 1; $i -lt $($Lines.Count); $i++) {
            $Line = $($Lines[$i].split(',')).foreach({ $_.trim().trim('>') })
            # Accounts for disconnected users
            if ($Line.count -eq 5) {
                $Line = @($Line[0], "$($null)", $Line[1], $Line[2], $Line[3], $Line[4] )
            }
            $CurUser = [PSCustomObject]::new()
            for ($j = 0; $j -lt $($Line.count); $j++) {
                $CurUser | Add-Member -MemberType NoteProperty -Name $Header[$j] -Value $Line[$j]
            }
            $CurUser
        }
    }
}
process {
    if (-not (Test-IsElevated)) {
        Write-Error -Message "Access Denied. Please run with Administrator privileges."
        exit 1
    }
    # Get a list of users logged on from query.exe, format it for powershell to process
    $QueryResults = Get-QueryUser
    # Accounts for only one user logged in
    $QueryTest = $($QueryResults | Select-Object -First 1)
    if (
        $QueryResults.Count -or
        (
            $QueryTest.USERNAME -is [String] -and
            -not [String]::IsNullOrEmpty($QueryTest.USERNAME) -and
            -not [String]::IsNullOrWhiteSpace($QueryTest.USERNAME)
        )
    ) {
        $script:HasError = $false
        $QueryResults | Where-Object {
    
            # For each session filter out the user that weren't specified in $User
            $_.UserName -in $User
    
        } | ForEach-Object {
            Write-Host "Found Logged In User: $($_.UserName)"
            if ($_.SessionName -like "console") {
                # We can't log out a user that is at the console.
                # We could do this logic in the Where-Object code block, but then there isn't an output of what was skipped.
                # https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/logoff#remarks
                # "You can't log off a user from the console session."
                Write-Host "Skipping user, can't log off a user($($_.UserName)) from the $($_.SessionName) session."
            }
            else {
                # Log off the user session with a matching ID
                logoff.exe $_.Id
                if ($LASTEXITCODE -gt 0) {
                    $script:HasError = $true
                    Write-Error "logoff.exe $($_.Id) returned exit code: $LASTEXITCODE"
                }
                else {
                    Write-Host "Logged Off User: $($_.UserName)"
                }
            }
        }
        if ($script:HasError) {
            exit 1
        }
    }
    else {
        Write-Output "No Users Logged In"
        exit 2
    }
}
end {}