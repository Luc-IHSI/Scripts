#Requires -Version 5.1

<#
.SYNOPSIS
    Returns exit code of 1 if any Enabled accounts that haven't been logged in over 90 days or a custom amount of days.
.DESCRIPTION
    Returns exit code of 1 if any Enabled accounts that haven't been logged in over 90 days or a custom amount of days.
.EXAMPLE
    No parameters needed.
    Returns exit code of 1 if any Enabled accounts that haven't been logged in over 90 days.
.EXAMPLE
    -IncludeDisabled
    Returns exit code of 1 if any Enabled or Disabled accounts that haven't been logged in over 90 days.
.EXAMPLE
    -Days 60
    Returns exit code of 1 if any Enabled accounts that haven't been logged in over 60 days.
.EXAMPLE
    -Days 60 -IncludeDisabled
    Returns exit code of 1 if any Enabled or Disabled accounts that haven't been logged in over 60 days.
.OUTPUTS
    None
.NOTES
    Minimum OS Architecture Supported: Windows 7, Windows Server 2012
    Exit code 1: Found users that haven't logged in over X days and are enabled.
    Exit code 2: Calling "net.exe user" or "Get-LocalUser" failed.
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

[CmdletBinding()]
param (
    [Parameter()]
    [int]
    $Days = 90,
    [Parameter()]
    [switch]
    $IncludeDisabled
)

begin {}
process {
    if ($Days -lt 0) {
        # Change negative days to the expected positive days
        $Days = 0 - $Days
    }
    $Accounts = if ($(Get-Command "Get-LocalUser").Name -like "Get-LocalUser") {
        try {
            Get-LocalUser | Select-Object Name, Enabled, SID, LastLogon
        }
        catch {
            exit 2
        }
    }
    else {
        # Get users from net.exe user
        $Data = $(net.exe user) | Select-Object -Skip 4
        # Check if the command ran the way we wanted and the exit code is 0
        if ($($Data | Select-Object -Last 2 | Select-Object -First 1) -like "*The command completed successfully.*" -and $LASTEXITCODE -eq 0) {
            # Process the output and get only the users
            $Users = $Data[0..($Data.Count - 3)] -split 's+' | Where-Object { -not $([String]::IsNullOrEmpty($_)) }
            # Loop through each user
            $Users | ForEach-Object {
                # Get the Account active property look for a Yes
                $Enabled = $(net.exe user $_) | Where-Object {
                    $_ -like "Account active*" -and
                    $($_ -split 's+' | Select-Object -Last 1) -like "Yes"
                }
                # Get the Last logon property
                $LastLogon = $(
                    $(
                        $(net.exe user $_) | Where-Object {
                            $_ -like "Last logon*"
                        }
                    ) -split 's+' | Select-Object -Skip 2
                ) -join ' '
                # Get the Password last set property
                $PasswordLastSet = $(
                    $(
                        $(net.exe user $_) | Where-Object {
                            $_ -like "Password last set*"
                        }
                    ) -split 's+' | Select-Object -Skip 3
                ) -join ' '
                # Output Name and Enabled almost like how Get-LocalUser displays it's data
                [PSCustomObject]@{
                    Name      = $_
                    Enabled   = if ($Enabled -like "*Yes*") { $true }else { $false }
                    LastLogon = if ($LastLogon -like "*Never*") { [DateTime]::Parse($PasswordLastSet) } else { [DateTime]::Parse($LastLogon) }
                }
            }
        }
        else {
            exit 2
        }
    }
    $Output = $Accounts | Where-Object {
        if ($IncludeDisabled) {
            $_.LastLogon -lt $(Get-Date).AddDays(0 - $Days)
        }
        else {
            $_.Enabled -and $_.LastLogon -lt $(Get-Date).AddDays(0 - $Days)
        }
    }
    $Output | Out-String | Write-Host
    if ($null -ne $Output) {
        exit 1
    }
}
end {}