#Requires -Version 5.1

<#
.SYNOPSIS
    This will return user session start and stop events.
.DESCRIPTION
    This will return user session start and stop events. Excluding system accounts.
.EXAMPLE
    No params needed
    Returns all login events for all users.
.EXAMPLE
     -UserName "Fred"
    Returns all user login events of the user Fred.
.EXAMPLE
     -Days 7
    Returns the last 7 days of login events for all users.
.EXAMPLE
     -Days 7 -UserName "Fred"
    Returns the last 7 days of login events for the user Fred.
.EXAMPLE
    PS C:> Get-User-Login-History.ps1 -Days 7 -UserName "Fred"
    Returns the last 7 days of login events for the user Fred.
.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Release Notes:
    Initial Release
.OUTPUTS
    Time                  Event        User  ID
    ----                  -----        ----  --
    10/7/2021 3:51:48 PM  SessionStop  User1 4634
    10/7/2021 3:51:48 PM  SessionStart User1 4624
.COMPONENT
    ManageUsers
By using this script, you indicate your acceptance of the following legal terms as well as our Terms of Use at https://www.ninjaone.com/terms-of-use.
    Ownership Rights: NinjaOne owns and will continue to own all right, title, and interest in and to the script (including the copyright). NinjaOne is giving you a limited license to use the script in accordance with these legal terms. 
    Use Limitation: You may only use the script for your legitimate personal or internal business purposes, and you may not share the script with another party. 
    Republication Prohibition: Under no circumstances are you permitted to re-publish the script in any script library or website belonging to or under the control of any other software provider. 
    Warranty Disclaimer: The script is provided “as is” and “as available”, without warranty of any kind. NinjaOne makes no promise or guarantee that the script will be free from defects or that it will meet your specific needs or expectations. 
    Assumption of Risk: Your use of the script is at your own risk. You acknowledge that there are certain inherent risks in using the script, and you understand and assume each of those risks. 
    Waiver and Release: You will not hold NinjaOne responsible for any adverse or unintended consequences resulting from your use of the script, and you waive any legal or equitable rights or remedies you may have against NinjaOne relating to your use of the script. 
    EULA: If you are a NinjaOne customer, your use of the script is subject to the End User License Agreement applicable to you (EULA).
#>

[CmdletBinding()]
param (
    # Specify one user
    [Parameter(Mandatory = $false)]
    [String]
    $UserName,
    # How far back in days you want to search, this is in 24 hour increments from the time it executes
    [Parameter(Mandatory = $false)]
    [int]
    $Days
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

    # System accounts that we don't want
    $SystemUsers = @(
        "SYSTEM"
        "NETWORK SERVICE"
        "LOCAL SERVICE"
    )
    # Filter for only getting session start and stop events from Security event log
    $FilterHashtable = @{
        LogName = "Security";
        id      = 4634, 4624
    }
    # If Days was specified then add this parameter
    if ($Days) {
        $FilterHashtable.Add("EndTime", (Get-Date).AddDays(-$Days))
    }
    # Creating a hash table for parameter splatting
    $Splat = @{
        FilterHashtable = $FilterHashtable
    }
}

process {
    if (-not (Test-IsElevated)) {
        Write-Error -Message "Access Denied. Please run with Administrator privileges."
        exit 1
    }
    # Get windows events, filter out everything but logins and logouts(Session starts and ends)
    Get-WinEvent @Splat | ForEach-Object {
        # UserName in the two event types are in different places in the Properties array
        if ($_.Id -eq 4634) {
            # Events with ID 4634 the user name is the second item in the array. Arrays start at 0 in PowerShell.
            $User = $_.Properties[1].Value
        }
        else {
            # Events with ID 4634 the user name is the sixth item in the array. Arrays start at 0 in PowerShell.
            $User = $_.Properties[5].Value
        }

        # Filter out system accounts and computer logins(Active Directory related)
        # DWM-0  = Desktop Window Manager
        # UMFD-0 = User Mode Framework Driver
        if ($SystemUsers -notcontains $User -and $User -notlike "DWM-*" -and $User -notlike "UMFD-*" -and $User -notlike "*$") {
            # If the UserName parameter was specified then only return that user's events
            if ($UserName -and $UserName -like $User) {
                # Write out to StandardOutput
                [PSCustomObject]@{
                    Time  = $_.TimeCreated
                    Event = if ($_.Id -eq 4634) { "SessionStop" } else { "SessionStart" }
                    User  = $User
                    ID    = $_.ID
                }
            } # If the UserName parameter was not specified return all users events
            elseif (-not $UserName) {
                # Write out to StandardOutput
                [PSCustomObject]@{
                    Time  = $_.TimeCreated
                    Event = if ($_.Id -eq 4634) { "SessionStop" } else { "SessionStart" }
                    User  = $User
                    ID    = $_.ID
                }
            }
        }
        # Null $User just in case the next loop iteration doesn't set it, we can then see that the user name is missing
        $User = $null
    }
}

end {}