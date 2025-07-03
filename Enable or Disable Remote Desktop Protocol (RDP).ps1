<#
.SYNOPSIS
    Enables or Disables RDP for workstations only.
.DESCRIPTION
    Enables or Disables RDP for workstations only.
.EXAMPLE
    -Disable
    Disables RDP for a workstation.
.EXAMPLE
    -Enable
    Enables RDP for a workstation.
.OUTPUTS
    None
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
#>
[CmdletBinding(DefaultParameterSetName = "Disable")]
param (
    [Parameter(Mandatory = $true, ParameterSetName = "Enable")]
    [switch]
    $Enable,
    [Parameter(Mandatory = $true, ParameterSetName = "Disable")]
    [switch]
    $Disable
)

begin {
    function Set-ItemProp {
        param (
            $Path,
            $Name,
            $Value,
            [ValidateSet("DWord", "QWord", "String", "ExpandedString", "Binary", "MultiString", "Unknown")]
            $PropertyType = "DWord"
        )
        # Do not output errors and continue
        $ErrorActionPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
        if (-not $(Test-Path -Path $Path)) {
            # Check if path does not exist and create the path
            New-Item -Path $Path -Force | Out-Null
        }
        if ((Get-ItemProperty -Path $Path -Name $Name)) {
            # Update property and print out what it was changed from and changed to
            $CurrentValue = Get-ItemProperty -Path $Path -Name $Name
            try {
                Set-ItemProperty -Path $Path -Name $Name -Value $Value -Force -Confirm:$false -ErrorAction Stop | Out-Null
            }
            catch {
                Write-Error $_
            }
            Write-Host "$Path$Name changed from $CurrentValue to $Value"
        }
        else {
            # Create property with value
            try {
                New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $PropertyType -Force -Confirm:$false -ErrorAction Stop | Out-Null
            }
            catch {
                Write-Error $_
            }
            Write-Host "Set $Path$Name to $Value"
        }
        $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Continue
    }
    function Test-IsElevated {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object System.Security.Principal.WindowsPrincipal($id)
        $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    # Registry settings
    $Path = 'HKLM:\System\CurrentControlSet\Control\Terminal Server'
    $Name = "fDenyTSConnections"
    $RegEnable = 0
    $RegDisable = 1

    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    $IsWorkstation = if ($osInfo.ProductType -eq 1) {
        $true
    }
    else {
        $false
    }
}
process {
    if (-not (Test-IsElevated)) {
        Write-Error -Message "Access Denied. Please run with Administrator privileges."
        exit 1
    }
    if (-not $IsWorkstation) {
        # System is a Domain Controller or Server
        Write-Error "System is a Domain Controller or Server. Skipping."
        exit 1
    }

    # Registry
    if ($Disable) {
        $RegCheck = $null
        $RegCheck = $(Get-ItemPropertyValue -Path $Path -Name $Name -ErrorAction SilentlyContinue)
        if ($null -eq $RegCheck) {
            $RegCheck = 0
        }
        if ($RegDisable -ne $RegCheck) {
            Set-ItemProp -Path $Path -Name $Name -Value $RegDisable
            Write-Host "Disabled $Path$Name"
        }
        else {
            Write-Host "$Path$Name already Disabled."
        }
    }
    elseif ($Enable) {
        $RegCheck = $null
        $RegCheck = $(Get-ItemPropertyValue -Path $Path -Name $Name -ErrorAction SilentlyContinue)
        if ($null -eq $RegCheck) {
            $RegCheck = 0
        }
        if ($RegEnable -ne $RegCheck) {
            Set-ItemProp -Path $Path -Name $Name -Value $RegEnable
            Write-Host "Enabled $Path$Name"
        }
        else {
            Write-Host "$Path$Name already Enabled."
        }
    }
    else {
        Write-Error "Enable or Disable was not specified."
        exit 1
    }

    # Firewall
    if ($Disable) {
        # Disable if was enabled and Disable was used
        try {
            Disable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction Stop
        }
        catch {
            Write-Error $_
            Write-Host "Remote Desktop firewall group is missing?"
        }
        Write-Host "Disabled Remote Desktop firewall rule groups."
    }
    elseif ($Enable) {
        # Enable if was disabled and Enable was used
        try {
            Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction Stop
        }
        catch {
            Write-Error $_
            Write-Host "Remote Desktop firewall group is missing?"
        }
        Write-Host "Enabled Remote Desktop firewall rule groups."
    }
    else {
        Write-Error "Enable or Disable was not specified."
        exit 1
    }
}
end {}