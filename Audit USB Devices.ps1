<#
.SYNOPSIS
    Alerts when a USB drive is detected and optionally saves the results to a Custom Field.
.DESCRIPTION
    Alerts when a USB drive is detected and optionally saves the results to a Custom Field.
.EXAMPLE
    (No Parameters)
    
    No USB Drives are present.
.EXAMPLE
    (No Parameters)

    C:\Users\KyleBohlander\Documents\bitbucket_clientscripts\client_scripts\src\Test-USBDrive.ps1 : A USB Drive has been detected!
    At line:1 char:1
    + .\src\Test-USBDrive.ps1
    + ~~~~~~~~~~~~~~~~~~~~~~~
        + CategoryInfo          : LimitsExceeded: (:) [Write-Error], Exception
        + FullyQualifiedErrorId : System.Exception,Test-USBDrive.ps1

    Index Caption                        SerialNumber     Partitions
    ----- -------                        ------------     ----------
        1 Samsung Flash Drive USB Device AA00000000000489          1

PARAMETER: -CustomFieldName "replaceMeWithACustomFieldName"
    Name of a custom field to save the results to. This is optional; results will also output to the activity log.

.OUTPUTS
    None
.NOTES
    Minimum supported OS: Windows 10, Server 2012 R2
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
    [String]$CustomFieldName
)

begin {
    # Grab CustomFieldName from dynamic script form
    if ($env:customFieldName -and $env:customFieldName -notlike "null") { $CustomFieldName = $env:customFieldName }

    # Initialize exit code
    $ExitCode = 0

    # Initialize generic list for the report
    $Report = New-Object System.Collections.Generic.List[String]
    $CustomFieldReport = New-Object System.Collections.Generic.List[String]
}
process {

    # Get a list of USB drives
    $USBDrives = if ($PSVersionTable.PSVersion.Major -ge 5) {
        Get-CimInstance win32_diskdrive | Where-Object { $_.InterfaceType -eq 'USB' }
    }
    else {
        Get-WmiObject win32_diskdrive | Where-Object { $_.InterfaceType -eq 'USB' }
    }

    # Alert if a USB drive is detected
    if ($USBDrives) {
        Write-Error -Message "A USB Drive has been detected!" -Category LimitsExceeded -Exception (New-Object -TypeName System.Exception)

        # Grab relevant information about the USB Drive
        $USBDrives | ForEach-Object {
            $Report.Add( ($_ | Format-Table Index, Caption, SerialNumber, Partitions | Out-String) )
            if ($CustomFieldName) { $CustomFieldReport.Add( ($_ | Format-List Index, Caption, SerialNumber, Partitions | Out-String) ) }

            $Report.Add( (Get-Partition -DiskNumber $_.Index | Get-Volume | Format-Table DriveLetter, FriendlyName, DriveType, HealthStatus, SizeRemaining, Size | Out-String) )
            if ($CustomFieldName) { $CustomFieldReport.Add( (Get-Partition -DiskNumber $_.Index | Get-Volume | Format-List DriveLetter, FriendlyName, DriveType, HealthStatus, SizeRemaining, Size | Out-String) ) }
        }

        # Change exit code to indicate failure/alert
        $ExitCode = 1
    }
    else {
        # If no drives were found we'll need to indicate that.
        $Report.Add("No USB Drives are present.")
        if ($CustomFieldName) { $CustomFieldReport.Add("No USB Drives are present.") }
    }

    # Write to the activity log
    Write-Host $Report

    # Save to custom field if given one
    if ($CustomFieldName) {
        Write-Host ""
        Ninja-Property-Set -Name $CustomFieldName -Value $CustomFieldReport
    }

    # Exit with appropriate exit code
    Exit $ExitCode
}
end {
    
    
    
}