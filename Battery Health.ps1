<#
.SYNOPSIS
    Monitoring - Windows - Battery Health
.DESCRIPTION
    This script will monitor the health of the battery in a Windows device and report back to NinjaOne.
.NOTES
    2023-03-26: Change static variable to use a parameter instead.
    2022-11-23; Refactor to use more reliable XML pathing and improve reliability.
    2022-02-15: Fix calculation error due to data types by casting to [int] before calculation.
    2022-02-15: Initial version
.LINK
    Blog post: https://homotechsual.dev/2022/12/22/NinjaOne-custom-fields-endless-possibilities/
#>
[CmdletBinding()]
param(
    # Path to output battery report files to.
    [System.IO.DirectoryInfo]$OutputPath = 'C:\RMM\Data'
)

if (-not (Test-Path -Path $OutputPath)) {
    New-Item -Type Directory -Path $OutputPath | Out-Null
}

& powercfg /batteryreport /XML /OUTPUT "$OutputPath\batteryreport.xml" | Out-Null

[xml]$Report = Get-Content "$OutputPath\batteryreport.xml"
     
$BatteryStatus = $Report.BatteryReport.Batteries.Battery | ForEach-Object {
    [PSCustomObject]@{
        DesignCapacity = [int]$_.DesignCapacity
        FullChargeCapacity = [int]$_.FullChargeCapacity
        CycleCount = [int]$_.CycleCount
        Id = $_.id
    }
}

if (!$BatteryStatus) {
    Ninja-Property-Set hasbatteries false | Out-Null
    Write-Output 'No batteries found.'
} else {
    Ninja-Property-Set hasbatteries true | Out-Null
}

$Battery = @{}

if ($BatteryStatus.Count -gt 1) {
    Ninja-Property-Set additionalbattery true | Out-Null
    $Battery = $BatteryStatus[0]
    Write-Output 'More than 1 battery found.'
} elseif ($BatteryStatus.Count -eq 1) {
    Ninja-Property-Set additionalbattery false | Out-Null
    Write-Output 'One battery found.'
    $Battery = $BatteryStatus[0]
} elseif ($BatteryStatus.Id) {
    Ninja-Property-Set additionalbattery false | Out-Null
    $Battery = $BatteryStatus
}

if ($Battery) {
    Write-Output 'Setting NinjaOne custom fields for first battery.'
  
    Ninja-Property-Set batteryidentifier $Battery.Id | Out-Null
    Ninja-Property-Set batterydesigncapacity $Battery.DesignCapacity | Out-Null
    Ninja-Property-Set batteryfullchargecapacity $Battery.FullChargeCapacity | Out-Null

    [int]$HealthPercent = ([int]$Battery.FullChargeCapacity / [int]$Battery.DesignCapacity) * 100

    Ninja-Property-Set batteryhealthpercent $HealthPercent | Out-Null
    Ninja-Property-Set batterycyclecount $Battery.CycleCount | Out-Null

    # Determine health status color
    $healthColor = if ($HealthPercent -ge 80) { "green" } else { "red" }

    # Create an HTML table with all battery information and a colored indicator
    $batteryInfo = @"
<style>
    .battery-table {
        width: 100%;
        border-collapse: collapse;
    }
    .battery-table th, .battery-table td {
        border: 1px solid #ddd;
        padding: 8px;
    }
    .battery-table th {
        background-color: #f2f2f2;
        text-align: left;
    }
    .battery-table .indicator {
        width: 10px;
    }
    .battery-table .good {
        background-color: green;
    }
    .battery-table .bad {
        background-color: red;
    }
</style>
<table class='battery-table'>
    <tr>
        <td class='indicator $healthColor'>&nbsp;</td>
        <td>
            <table class='battery-table'>
                <tr>
                    <th>Property</th>
                    <th>Value</th>
                </tr>
                <tr>
                    <td>Identifier</td>
                    <td>$($Battery.Id)</td>
                </tr>
                <tr>
                    <td>Design Capacity</td>
                    <td>$($Battery.DesignCapacity) mWh</td>
                </tr>
                <tr>
                    <td>Full Charge Capacity</td>
                    <td>$($Battery.FullChargeCapacity) mWh</td>
                </tr>
                <tr>
                    <td>Health Percent</td>
                    <td style='color: $healthColor;'>$HealthPercent%</td>
                </tr>
                <tr>
                    <td>Cycle Count</td>
                    <td>$($Battery.CycleCount)</td>
                </tr>
            </table>
        </td>
    </tr>
</table>
"@

    Ninja-Property-Set batteryinfo $batteryInfo | Out-Null
    Write-Output $batteryInfo
} else {
    Write-Output 'Failed to parse battery status correctly.'
}