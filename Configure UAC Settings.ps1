#Requires -Version 2.0

<#
.SYNOPSIS
    Configures UAC.
.DESCRIPTION
    Configures UAC to defaults if no parameters are specified.
.EXAMPLE
    No parameters needed.
    Sets all UAC settings to Microsoft's defaults.
.EXAMPLE
     -ConsentPromptBehaviorAdmin 5
    Sets ConsentPromptBehaviorAdmin to 5
.EXAMPLE
    PS C:> Set-Uac.ps1
    Sets all UAC settings to MS defaults.
.OUTPUTS
    None
.NOTES
    Minimum OS Architecture Supported: Windows 7, Windows Server 2012
    This script will show before and after UAC settings.
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
    LocalUserAccountManagement
#>

[CmdletBinding()]
param (
    [Parameter()][ValidateRange(0, 5)][int]$ConsentPromptBehaviorAdmin = 5,
    [Parameter()][ValidateRange(0, 3)][int]$ConsentPromptBehaviorUser = 3,
    [Parameter()][ValidateRange(0, 1)][int]$EnableInstallerDetection = 1,
    [Parameter()][ValidateRange(0, 1)][int]$EnableLUA = 1,
    [Parameter()][ValidateRange(0, 1)][int]$EnableVirtualization = 1,
    [Parameter()][ValidateRange(0, 1)][int]$PromptOnSecureDesktop = 1,
    [Parameter()][ValidateRange(0, 1)][int]$ValidateAdminCodeSignatures = 0,
    [Parameter()][ValidateRange(0, 1)][int]$FilterAdministratorToken = 0
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
    function Set-ItemProp {
        param (
            $Path,
            $Name,
            $Value,
            [ValidateSet("DWord", "QWord", "String", "ExpandedString", "Binary", "MultiString", "Unknown")]
            $PropertyType = "DWord"
        )
        if ((Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue)) {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Force -Confirm:$false | Out-Null
        }
        else {
            New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $PropertyType -Force -Confirm:$false | Out-Null
        }
    }
}
process {
    if (-not (Test-IsElevated)) {
        Write-Error -Message "Access Denied. Please run with Administrator privileges."
        exit 1
    }
    $path = "HKLM:SOFTWAREMicrosoftWindowsCurrentVersionPoliciesSystem"
    $filter = "ConsentPromptBehaviorAdmin|ConsentPromptBehaviorUser|EnableInstallerDetection|EnableLUA|EnableVirtualization|PromptOnSecureDesktop|ValidateAdminCodeSignatures|FilterAdministratorToken"
    Write-Host "Before:"
    (Get-ItemProperty $path).psobject.properties | Where-Object { $_.name -match $filter } | Select-Object name, value

    try {
        $filter -split '|' | ForEach-Object {
            Set-ItemProp -Path $Path -Name $_ -Value (Get-Variable -Name $_).Value
        }
    }
    catch {
        Write-Error $_
        exit 1
    }

    Write-Host "After:"
    (Get-ItemProperty $path).psobject.properties | Where-Object { $_.name -match $filter } | Select-Object name, value
}
end {}