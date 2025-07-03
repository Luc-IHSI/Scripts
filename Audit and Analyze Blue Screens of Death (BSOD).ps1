#Requires -Version 5.1

<#
.SYNOPSIS
    Conditional script for detecting BSOD's. Uses BlueScreenView from Nirsoft.
.DESCRIPTION
    Conditional script for detecting BSOD's. Uses BlueScreenView from Nirsoft.
    Will always show the number of Unexpected shutdowns if system is setup to log those events.
        This doesn't always mean that there was a BSOD as this includes things like holding the power button or pressing the rest button.
    When a mini dump is detected in C:WindowsMinidump then this will output the results and exit with an exit code of 1.
    When none have been found then this will exit with an exit code of 0.
    When it couldn't download or extract BlueScreenView then this will exit with an exit code of 2.
.OUTPUTS
    None
.NOTES
    This should be the default, but in case this was modified instructions below.
    Minimal Setup:
        Open System Properties.
        Click on Settings under Startup and Recovery.
        Make sure that "Write an event to the system log" is checked.
        Under System failure change to "Write debugging information" to Automatic memory dump.
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Release Notes:
    Initial Release
    (c) 2023 NinjaOne
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
param ()

process {
    if (-not (Test-IsElevated)) {
        Write-Error -Message "Access Denied. Please run with Administrator privileges."
        exit 1
    }

    # Get unexpected shutdown events from System log
    $UnexpectedShutdownEvents = Get-WinEvent -FilterHashtable @{LogName = 'System'; ID = 6008 }
    if ($UnexpectedShutdownEvents) {
        Write-Host "Unexpected shutdowns found: $($UnexpectedShutdownEvents.Count)"
        Write-Host ""
    }

    # Check if any minidumps exist and exit if none are found
    if (-not $(Get-ChildItem -Path "C:WindowsMinidump" -ErrorAction SilentlyContinue)) {
        Write-Host "No mini dumps found."
        exit 0
    }
    
    # Download Blue Screen View, run, and export results to a csv file
    try {
        Invoke-WebRequest -Uri $BlueScreenViewUrl -OutFile $ZipPath -ErrorAction Stop
        Expand-Archive -Path $ZipPath -DestinationPath $ENV:Temp -Force -ErrorAction Stop
        Start-Process -FilePath $ExePath -ArgumentList "/scomma ""$CsvPath""" -Wait -ErrorAction Stop
    }
    catch {
        Write-Host "Blue Screen View Command has Failed: $($_.Exception.Message)"
        # Clean Up
        Remove-DownloadedFiles -Path $CsvPath, $ZipPath, $ExePath, "$($ENV:Temp)BlueScreenView.chm", "$($ENV:Temp)readme.txt"
        exit 2
    }

    # Convert the CSV to an array of objects
    $MiniDumps = Get-Content -Path $CsvPath |
        ConvertFrom-Csv -Delimiter ',' -Header $Header |
        Select-Object -Property @{
            'n' = "Timestamp";
            'e' = { [DateTime]::Parse($_.timestamp, [System.Globalization.CultureInfo]::CurrentCulture) }
        }, Dumpfile, Reason, Errorcode, CausedByDriver

    # Clean Up
    Remove-DownloadedFiles -Path $CsvPath, $ZipPath, $ExePath, "$($ENV:Temp)BlueScreenView.chm", "$($ENV:Temp)readme.txt"

    # Output the results
    $MiniDumps | Out-String | Write-Host

    if ($MiniDumps) {
        exit 1
    }
    exit 0
}
begin {
    function Test-IsElevated {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object System.Security.Principal.WindowsPrincipal($id)
        $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    function Remove-DownloadedFiles {
        param([string[]]$Path)
        process { Remove-Item -Path $Path -Force -ErrorAction SilentlyContinue }
    }

    # CSV Headers
    $Header = @(
        "Dumpfile"
        "Timestamp"
        "Reason"
        "Errorcode"
        "Parameter1"
        "Parameter2"
        "Parameter3"
        "Parameter4"
        "CausedByDriver"
    )

    # Build path variables
    $CsvFileName = "bluescreenview-export.csv"
    $BlueScreenViewZip = "bluescreenview.zip"
    $BlueScreenViewExe = "BlueScreenView.exe"
    $BlueScreenViewUrl = "https://www.nirsoft.net/utils/$BlueScreenViewZip"
    $ZipPath = Join-Path -Path $ENV:Temp -ChildPath $BlueScreenViewZip
    $ExePath = Join-Path -Path $ENV:Temp -ChildPath $BlueScreenViewExe
    $CsvPath = Join-Path -Path $ENV:Temp -ChildPath $CsvFileName
}
end {}