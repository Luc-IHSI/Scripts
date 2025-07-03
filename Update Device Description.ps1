#Requires -Version 4

<#
.SYNOPSIS
    Updates the current device description.
.DESCRIPTION
    Updates the current device description.
By using this script, you indicate your acceptance of the following legal terms as well as our Terms of Use at https://www.ninjaone.com/terms-of-use.
    Ownership Rights: NinjaOne owns and will continue to own all right, title, and interest in and to the script (including the copyright). NinjaOne is giving you a limited license to use the script in accordance with these legal terms. 
    Use Limitation: You may only use the script for your legitimate personal or internal business purposes, and you may not share the script with another party. 
    Republication Prohibition: Under no circumstances are you permitted to re-publish the script in any script library or website belonging to or under the control of any other software provider. 
    Warranty Disclaimer: The script is provided “as is” and “as available”, without warranty of any kind. NinjaOne makes no promise or guarantee that the script will be free from defects or that it will meet your specific needs or expectations. 
    Assumption of Risk: Your use of the script is at your own risk. You acknowledge that there are certain inherent risks in using the script, and you understand and assume each of those risks. 
    Waiver and Release: You will not hold NinjaOne responsible for any adverse or unintended consequences resulting from your use of the script, and you waive any legal or equitable rights or remedies you may have against NinjaOne relating to your use of the script. 
    EULA: If you are a NinjaOne customer, your use of the script is subject to the End User License Agreement applicable to you (EULA).
.EXAMPLE
    -Description "Kitchen Computer"
    
    Attempting to set device description to 'Kitchen Computer'.


    SystemDirectory : C:\Windows\system32
    Organization    : vm.net
    BuildNumber     : 9600
    RegisteredUser  : NA
    SerialNumber    : 00252-70000-00000-AA382
    Version         : 6.3.9600

    Successfully set device description to 'Kitchen Computer'.


PARAMETER: -Description "ReplaceMeWithADeviceDescription"
    Specify the device description you would like to set.

PARAMETER: -ClearDescription
    Clear the current device description.

.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2012 R2
    Release Notes: Initial Release
#>

[CmdletBinding()]
param (
    [Parameter()]
    [String]$Description,
    [Parameter()]
    [Switch]$ClearDescription = [System.Convert]::ToBoolean($env:clearDeviceDescription)
)

begin {
    if($env:deviceDescription -and $env:deviceDescription -notlike "null"){ $Description = $env:deviceDescription }

    # Trim any leading or trailing whitespace from the description, if it exists
    if ($Description) {
        $Description = $Description.Trim()
    }

    # Ensure that a description is provided if clearing the description is not requested
    if (!$Description -and !$ClearDescription) {
        Write-Host -Object "[Error] You must provide a description to set."
        exit 1
    }

    # Ensure that both clearing and setting the description are not requested simultaneously
    if ($ClearDescription -and $Description) {
        Write-Host -Object "[Error] You cannot clear and set the device description at the same time."
        exit 1
    }

    # Clear the description if requested
    if ($ClearDescription) {
        $Description = $Null
    }

    # Measure the length of the description
    $DescriptionLength = $Description | Measure-Object -Character | Select-Object -ExpandProperty Characters
    # Warn if the description is longer than 40 characters
    if ($DescriptionLength -ge 40) {
        Write-Host -Object "[Warning] The description '$Description' is greater than 40 characters. It may appear trimmed in certain situations."
    }

    # Function to check if the script is running with elevated (administrator) privileges
    function Test-IsElevated {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object System.Security.Principal.WindowsPrincipal($id)
        $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    if (!$ExitCode) {
        $ExitCode = 0
    }
}
process {
    # Check if the script is running with elevated (administrator) privileges
    if (!(Test-IsElevated)) {
        Write-Host -Object "[Error] Access Denied. Please run with Administrator privileges."
        exit 1
    }

    try {
        Write-Host -Object "Attempting to set device description to '$Description'."
        # Determine the PowerShell version and set the operating system description accordingly
        if ($PSVersionTable.PSVersion.Major -lt 5) {
            # Use Get-WmiObject for PowerShell versions less than 5
            Get-WmiObject -Class Win32_OperatingSystem -ErrorAction Stop | Set-WmiInstance -Property @{ 'Description' = $Description } -ErrorAction Stop
        }
        else {
            # Use Get-CimInstance for PowerShell version 5 or greater
            Get-CimInstance -Class Win32_OperatingSystem -ErrorAction Stop | Set-CimInstance -Property @{ 'Description' = $Description } -ErrorAction Stop
        }
        Write-Host -Object "Successfully set device description to '$Description'."
    }
    catch {
        # Handle any errors that occur while retrieving the device description
        Write-Host -Object "[Error] Failed to set the device description."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        exit 1
    }

    exit $ExitCode
}
end {
    
    
    
}