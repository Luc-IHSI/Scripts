[CmdletBinding()]
param (
    [string]$CustomField
)

begin {
    $Epoch = [DateTime]'1/1/1970'
    if ($env:customFieldName -and $env:customFieldName -notlike "null") {
        $CustomField = $env:customFieldName
    }
    Write-Host ""
}

process {
    $dates = @()

    try {
        Get-ChildItem -Path "HKLM:\System\Setup\Source*" -ErrorAction SilentlyContinue | ForEach-Object {
            $ts = Get-ItemPropertyValue -Path $_.PSPath -Name "InstallDate" -ErrorAction SilentlyContinue
            if ($ts) {
                $dates += [System.TimeZone]::CurrentTimeZone.ToLocalTime($Epoch.AddSeconds($ts))
            }
        }
    } catch {}

    try {
        $ts = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name "InstallDate" -ErrorAction SilentlyContinue
        if ($ts) {
            $dates += [System.TimeZone]::CurrentTimeZone.ToLocalTime($Epoch.AddSeconds($ts))
        }
    } catch {}

    try {
        $systemInfo = systeminfo.exe | Out-String
        if ($systemInfo -match "Original Install Date:\s+(.+?)\r?\n") {
            $dates += [datetime]::Parse($matches[1])
        }
    } catch {}

    try {
        $wmiDate = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue).InstallDate
        if ($wmiDate) {
            $dates += $wmiDate
        }
    } catch {}

    try {
        if ($PSVersionTable.PSVersion.Major -ge 5 -and $PSVersionTable.PSVersion.Minor -ge 1) {
            $ci = Get-ComputerInfo -Property WindowsInstallDateFromRegistry, OsInstallDate -ErrorAction SilentlyContinue
            if ($ci.WindowsInstallDateFromRegistry) { $dates += $ci.WindowsInstallDateFromRegistry }
            if ($ci.OsInstallDate) { $dates += $ci.OsInstallDate }
        }
    } catch {}

    $InstallDate = $dates | Sort-Object | Select-Object -First 1

    if ($InstallDate) {
        $day   = $InstallDate.Day
        $month = $InstallDate.ToString("MMMM")
        $year  = $InstallDate.Year
        $time  = $InstallDate.ToString("hh:mm tt")

        $htmlContent = @"
<div style='border:1px solid #ccc; border-radius:10px; padding:16px; background-color:#ffffff; color:#333333; font-family:Segoe UI, sans-serif; width:100%; max-width:400px; box-shadow:0 2px 8px rgba(0,0,0,0.1);'>
    <h3 style='margin-top:0; color:#0078D4;'>�️ Windows Install Date</h3>
    <div style='margin-bottom:10px;'><strong>� Day:</strong> $day</div>
    <div style='margin-bottom:10px;'><strong>� Month:</strong> $month</div>
    <div style='margin-bottom:10px;'><strong>� Year:</strong> $year</div>
    <div style='margin-bottom:10px;'><strong>⏰ Time:</strong> $time</div>
</div>
"@
    } else {
        $htmlContent = @"
<div style='border:1px solid #ccc; border-radius:10px; padding:16px; background-color:#ffffff; color:#333333; font-family:Segoe UI, sans-serif; width:100%; max-width:400px; box-shadow:0 2px 8px rgba(0,0,0,0.1);'>
    <h3 style='margin-top:0; color:#D9534F;'>❌ Install Date Unknown</h3>
    <p>Unable to determine the Windows install date from any known method.</p>
</div>
"@
    }

    if ($CustomField) {
        Ninja-Property-Set -Name $CustomField -Value $htmlContent
    }

    Write-Host "Install Date: $InstallDate"
}

end {}
