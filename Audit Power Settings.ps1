#Requires -Version 5.1

<#
.SYNOPSIS
    Retrieves "Sleep after" and "Turn off display after" power settings in minutes and outputs them as HTML to a NinjaOne custom field.
.DESCRIPTION
    Queries the active power plan settings using powercfg, extracts the "Sleep after" and "Turn off display after" settings,
    converts them from seconds to minutes (or displays "Never" if 0), and outputs them as an HTML table.
.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Must be run with Administrator privileges.
#>

[CmdletBinding()]
param ()

begin {
    function Test-IsElevated {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object System.Security.Principal.WindowsPrincipal($id)
        $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    function Get-PowerPlan {
        [CmdletBinding()]
        param ([Switch]$Active)
        if ($Active) {
            $PowerPlan = powercfg.exe /getactivescheme
            $PowerPlan = ($PowerPlan -replace "Power Scheme GUID:" -split "(?=\S{8}-\S{4}-\S{4}-\S{4}-\S{12})" -split '\(' -replace '\)') | Where-Object { $_ -ne " " }
            $PowerPlan = @(
                [PSCustomObject]@{
                    Name = $($PowerPlan | Where-Object { $_ -notmatch "\S{8}-\S{4}-\S{4}-\S{4}-\S{12}" })
                    GUID = $($PowerPlan | Where-Object { $_ -match "\S{8}-\S{4}-\S{4}-\S{4}-\S{12}" })
                }
            )
        }
        return $PowerPlan
    }

    function Get-PowerSettings {
        [CmdletBinding()]
        param ([string[]]$TargetSettings)
        process {
            $PowerSubgroups = powercfg.exe /Q | Select-String "Subgroup GUID:"
            $PowerSubgroups = ($PowerSubgroups -replace "Subgroup GUID:" -replace '\(' -replace '\)').trim() | ForEach-Object {
                [PSCustomObject]@{
                    SubName = ($_ -split "\s{2,}" | Where-Object { $_ -notmatch "(\S{8}-\S{4}-\S{4}-\S{4}-\S{12})" })
                    SubGUID = ($_ -split "\s{2,}" | Where-Object { $_ -match "(\S{8}-\S{4}-\S{4}-\S{4}-\S{12})" })
                }
            }

            $PowerSettings = ForEach ($Subgroup in $PowerSubgroups) {
                $Settings = powercfg.exe /Q SCHEME_CURRENT $Subgroup.SubGUID | Select-String "Power Setting GUID:"
                ($Settings -replace "Power Setting GUID:" -replace '\(' -replace '\)').trim() | ForEach-Object {
                    [PSCustomObject]@{
                        Name    = ($_ -split "\s{2,}" | Where-Object { $_ -notmatch "(\S{8}-\S{4}-\S{4}-\S{4}-\S{12})" })
                        GUID    = ($_ -split "\s{2,}" | Where-Object { $_ -match "(\S{8}-\S{4}-\S{4}-\S{4}-\S{12})" })
                        SubName = $Subgroup.SubName
                        SubGUID = $Subgroup.SubGUID
                    }
                }
            }

            $FilteredSettings = $PowerSettings | Where-Object { $_.Name -in $TargetSettings }

            $Results = ForEach ($PowerSetting in $FilteredSettings) {
                $ACValue = powercfg.exe /Q SCHEME_CURRENT $PowerSetting.SubGUID $PowerSetting.GUID | Select-String "Current AC Power Setting Index:" | ForEach-Object { ($_ -split ":")[1].Trim() }
                $DCValue = powercfg.exe /Q SCHEME_CURRENT $PowerSetting.SubGUID $PowerSetting.GUID | Select-String "Current DC Power Setting Index:" | ForEach-Object { ($_ -split ":")[1].Trim() }

                $ACValue = [int32]$ACValue
                $DCValue = [int32]$DCValue

                $ACMinutes = if ($ACValue -eq 0) { "Never" } else { "{0} minutes" -f ([math]::Round($ACValue / 60)) }
                $DCMinutes = if ($DCValue -eq 0) { "Never" } else { "{0} minutes" -f ([math]::Round($DCValue / 60)) }

                [PSCustomObject]@{
                    Setting           = $PowerSetting.Name
                    "When Plugged In" = $ACMinutes
                    "When On Battery" = $DCMinutes
                    Units             = "Minutes"
                }
            }

            return $Results
        }
    }

function ConvertTo-HtmlTable {
    param (
        [Parameter(Mandatory = $true)] [Array]$Data,
        [string]$Title
    )

    $Html = ""

    if ($Title) {
        $Html += "<h2 style='font-family: Segoe UI, sans-serif; font-size: 20px; color: #2c3e50; margin-bottom: 12px;'></h2>"
    }

    $Html += @"
<table style='
    width: 100%;
    border-collapse: collapse;
    font-family: Segoe UI, sans-serif;
    font-size: 14px;
    color: #333;
'>
    <thead>
        <tr style='background-color: #f0f0f0; border-bottom: 2px solid #ccc;'>
"@

    foreach ($column in $Data[0].psobject.Properties.Name) {
        $Html += "<th style='padding: 10px; text-align: left;'>$column</th>"
    }

    $Html += "</tr></thead><tbody>"

    foreach ($row in $Data) {
        $Html += "<tr>"
        foreach ($column in $row.psobject.Properties.Name) {
            $value = $row.$column
            $Html += "<td style='padding: 10px; border-bottom: 1px solid #eee;'>$value</td>"
        }
        $Html += "</tr>"
    }

    $Html += "</tbody></table>"

    return $Html
}



}

process {
    if (-not (Test-IsElevated)) {
        Write-Error -Message "Access Denied. Please run with Administrator privileges."
        exit 1
    }

    $ActivePowerPlan = Get-PowerPlan -Active | Select-Object Name -ExpandProperty Name
    if (-not $ActivePowerPlan) {
        Write-Error "[Error] Unable to retrieve power plan!"
        exit 1
    }

    $TargetSettings = @("Sleep after", "Turn off display after")
    $CurrentPowerSettings = Get-PowerSettings -TargetSettings $TargetSettings | Sort-Object Setting

    if (-not $CurrentPowerSettings) {
        Write-Error "[Error] Unable to retrieve power settings!"
        exit 1
    }

    $customFieldName = "powerSettingsSummary"
    $html = ConvertTo-HtmlTable -Data $CurrentPowerSettings -Title "Power Settings Summary"
    Write-Host "`n$html"

    Ninja-Property-Set $customFieldName $html
}

end {}
