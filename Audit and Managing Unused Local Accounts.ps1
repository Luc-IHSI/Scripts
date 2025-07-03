#Requires -Version 5.1

<#
.SYNOPSIS
    Condition script for unused local account on windows
.DESCRIPTION
    Condition script for unused local account on windows
.EXAMPLE
     -Days 30
    Checks for accounts that have not logged in for more than 30 days
.EXAMPLE
    PS C:> Test-UnusedLocalAccounts.ps1 -Days 30
    Checks for accounts that have not logged in for more than 30 days
.OUTPUTS
    None
.NOTES
    Minimum supported OS: Windows 10, Server 2016
    Release Notes:
    Initial release
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
    [Parameter()]
    [int]
    $Days = 30
)

begin {
    function Test-StringEmpty {
        param([string]$Text)
        # Returns true if string is empty, null, or whitespace
        process { [string]::IsNullOrEmpty($Text) -or [string]::IsNullOrWhiteSpace($Text) }
    }
    if (-not $(Test-StringEmpty -Text $env:Days)) {
        $Days = $env:Days
    }
}
process {
    # Check if Get-LocalUser is available on this system
    if (-not $(Get-Command -Name "Get-LocalUser" -ErrorAction SilentlyContinue)) {
        Write-Error "The command Get-LocalUser is not available on this system."
        exit 2
    }

    $UnusedAccounts = Get-LocalUser |
        Where-Object {
            ($(Test-StringEmpty -Text $_.LastLogon) -or $_.LastLogon -le (Get-Date).AddDays(-$Days)) -and
            $_.Enabled
        } |
        Select-Object Name, LastLogon |
        ForEach-Object {
            [PSCustomObject]@{
                Name      = $_.Name
                LastLogon = $_.LastLogon
            }
        }
    if ($UnusedAccounts) {
        Write-Host "Accounts that have not logged in for the past $Days days:"
        $UnusedAccounts | ForEach-Object {
            Write-Host "$($_.Name): $($_.LastLogon)"
        }
        exit 1
    }
    exit 0
}
end {
    $ScriptVariables = @(
        [PSCustomObject]@{
            name           = "Days"
            calculatedName = "days"
            required       = $false
            defaultValue   = [PSCustomObject]@{
                type  = "TEXT"
                value = "30"
            }
            valueType      = "TEXT"
            valueList      = $null
            description    = "Accounts older than this number in days."
        }
    )
}