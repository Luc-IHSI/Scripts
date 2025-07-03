#Requires -Version 5.1

<#
.SYNOPSIS
    Reports on or starts services for Automatic Services that are not currently running. Services set as 'Delayed Start' or 'Trigger Start' are ignored.
.DESCRIPTION
    Reports on or starts services for Automatic Services that are not currently running. Services set as 'Delayed Start' or 'Trigger Start' are ignored.
.EXAMPLE
    (No Parameters)
    
    Matching Services found!

    Name    Description                                         
    ----    -----------                                         
    SysMain Maintains and improves system performance over time.

PARAMETER: -IgnoreServices "ExampleServiceName"
    A comma separated list of service names to ignore.

PARAMETER: -StartFoundServices
    Attempts to start any services found matching the criteria.

.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Release Notes: Initial Release
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
    [String]$IgnoreServices,
    [Parameter()]
    [Switch]$StartFoundServices = [System.Convert]::ToBoolean($env:startFoundServices)
)

begin {
    # Replace script parameters with form variables
    if($env:servicesToExclude -and $env:servicesToExclude -notlike "null"){ $IgnoreServices = $env:servicesToExclude }

    # Get the last startup time of the operating system.
    $LastBootDateTime = Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -ExpandProperty LastBootUpTime
    if ($LastBootDateTime -gt $(Get-Date).AddMinutes(-15)) {
        $Uptime = New-TimeSpan $LastBootDateTime (Get-Date) | Select-Object -ExpandProperty TotalMinutes
        Write-Host "Current uptime is $([math]::Round($Uptime)) minutes."
        Write-Host "[Error] Please wait at least 15 minutes after startup before running this script."
        exit 1
    }

    # Define a function to test if the current user has elevated (administrator) privileges.
    function Test-IsElevated {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object System.Security.Principal.WindowsPrincipal($id)
        $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    $ExitCode = 0
}
process {
    # Check if the script is running with Administrator privileges.
    if (!(Test-IsElevated)) {
        Write-Host -Object "[Error] Access Denied. Please run with Administrator privileges."
        exit 1
    }

    # Define a string of characters that are invalid for service names.
    $InvalidServiceNameCharacters = "\\|/|:"
    # Create a list to hold the names of services to ignore.
    $ServicesToIgnore = New-Object System.Collections.Generic.List[string]

    # If there are services to ignore and they are separated by commas, split the string into individual service names.
    if ($IgnoreServices -and $IgnoreServices -match ",") {
        $IgnoreServices -split "," | ForEach-Object {
            # Check each service name for invalid characters or excessive length.
            if ($_.Trim() -match $InvalidServiceNameCharacters) {
                Write-Host "[Error] Service Name contains one of the invalid characters '\/:'. $_ is not a valid service to ignore."
                $ExitCode = 1
                return
            }

            if (($_.Trim()).Length -gt 256) {
                Write-Host "[Error] Service Name is greater than 256 characters. $_ is not a valid service to ignore. "
                $ExitCode = 1
                return
            }

            # Add valid services to the ignore list.
            $ServicesToIgnore.Add($_.Trim())
        }
    }
    elseif ($IgnoreServices) {
        # For a single service name, perform similar validation and add if valid.
        $ValidService = $True

        if ($IgnoreServices.Trim() -match $InvalidServiceNameCharacters) {
            Write-Host "[Error] Service Name contains one of the invalid characters '\/:'. '$IgnoreServices' is not a valid service to ignore. "
            $ExitCode = 1
            $ValidService = $False
        }

        if (($IgnoreServices.Trim()).Length -gt 256) {
            Write-Host "[Error] Service Name is greater than 256 characters. '$IgnoreServices' is not a valid service to ignore. "
            $ExitCode = 1
            $ValidService = $False
        }

        if ($ValidService) {
            $ServicesToIgnore.Add($IgnoreServices.Trim())
        }
    }

    # Create a list to hold non-running services that are set to start automatically.
    $NonRunningAutoServices = New-Object System.Collections.Generic.List[object]
    Get-Service | Where-Object { $_.StartType -like "Automatic" -and $_.Status -ne "Running" } | ForEach-Object {
        $NonRunningAutoServices.Add($_)
    }

    # Remove services from the list that have triggers or are set to delayed start,
    if ($NonRunningAutoServices.Count -gt 0) {
        $TriggerServices = Get-ChildItem -Path "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\*\*" -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "TriggerInfo" }
        $TriggerServices = $TriggerServices | Select-Object -ExpandProperty PSParentPath | Split-Path -Leaf
        foreach ($TriggerService in $TriggerServices) {
            $NonRunningAutoServices.Remove(($NonRunningAutoServices | Where-Object { $_.ServiceName -match $TriggerService })) | Out-Null
        }

        $DelayedStartServices = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\*" | Where-Object { $_.DelayedAutoStart -eq 1 }
        $DelayedStartServices = $DelayedStartServices | Select-Object -ExpandProperty PSChildName
        foreach ($DelayedStartService in $DelayedStartServices) {
            $NonRunningAutoServices.Remove(($NonRunningAutoServices | Where-Object { $_.ServiceName -match $DelayedStartService })) | Out-Null
        }
    }

    # Remove explicitly ignored services from the list of non-running automatic services.
    if ($ServicesToIgnore.Count -gt 0 -and $NonRunningAutoServices.Count -gt 0) {
        foreach ($ServiceToIgnore in $ServicesToIgnore) {
            if ($NonRunningAutoServices.ServiceName -contains $ServiceToIgnore) {
                $NonRunningAutoServices.Remove(($NonRunningAutoServices | Where-Object { $_.ServiceName -match [Regex]::Escape($ServiceToIgnore) })) | Out-Null
            }
        }
    }

    # If there are still non-running automatic services left, display their names.
    # Otherwise, indicate no stopped automatic services were detected.
    if ($NonRunningAutoServices.Count -gt 0) {
        Write-Host "Matching Services found!"

        # Add Description to report.
        $ServicesReport = New-Object System.Collections.Generic.List[object]
        $NonRunningAutoServices | ForEach-Object {
            $Description = Get-CimInstance -ClassName Win32_Service -Filter "Name = '$($_.ServiceName)'" | Select-Object @{
                Name       = "Description"
                Expression = {
                    $Characters = $_.Description | Measure-Object -Character | Select-Object -ExpandProperty Characters
                    if ($Characters -gt 100) {
                        "$(($_.Description).SubString(0,100))..."
                    }
                    else {
                        $_.Description
                    }
                }
            }
            $ServicesReport.Add(
                [PSCustomObject]@{
                    Name = $_.ServiceName
                    Description = $Description | Select-Object -ExpandProperty Description
                }
            )
        }

        # Output report to activity log.
        $ServicesReport | Sort-Object Name | Format-Table -Property Name,Description -AutoSize | Out-String | Write-Host
    }
    else {
        Write-Host "No stopped automatic services detected!"
    }

    # Exit the script if there are no services to start or if starting services is not requested.
    if (!$StartFoundServices -or !($NonRunningAutoServices.Count -gt 0)) {
        exit $ExitCode
    }

    # Attempt to start each non-running automatic service up to three times.
    # Log success or error messages accordingly.
    $NonRunningAutoServices | ForEach-Object {
        Write-Host "`nAttempting to start $($_.ServiceName)."
        $Attempt = 1
        while ($Attempt -le 3) {
            Write-Host -Object "Attempt: $Attempt"
            try {
                $_ | Start-Service -ErrorAction Stop
                Write-Host -Object "Successfully started $($_.ServiceName)."
                $Attempt = 4
            }
            catch {
                Write-Host -Object "[Error] $($_.Exception.Message)"
                if ($Attempt -eq 3) { $ExitCode = 1 }
            }
            $Attempt++
        }
    }
    
    exit $ExitCode
}
end {
    
    
    
}