$ipLogo = "#️⃣"
$cityLogo = "�"
$countryLogo = "�"

function Get-PublicIPAddress {
    $maxRetries = 3
    $retryCount = 0
    $ip = $null

    while ($retryCount -lt $maxRetries -and $null -eq $ip) {
        try {
            $ip = (Invoke-WebRequest -UseBasicParsing -Uri 'http://ifconfig.me/ip').Content.Trim()
        }
        catch {
            Write-Warning "Attempt $($retryCount + 1): Unable to connect to ifconfig.me. Retrying..."
            Start-Sleep -Seconds 2
            $retryCount++
        }
    }

    if ($null -eq $ip) {
        throw "Failed to retrieve public IP address after $maxRetries attempts."
    }

    return $ip
}

function Get-IPInfo {
    param (
        [string]$ip
    )

    $maxRetries = 3
    $retryCount = 0
    $result = $null

    while ($retryCount -lt $maxRetries -and $null -eq $result) {
        try {
            $result = Invoke-RestMethod -Uri "http://ipinfo.io/$ip" | Select-Object ip, city, region, country
        }
        catch {
            Write-Warning "Attempt $($retryCount + 1): Unable to connect to ipinfo.io. Retrying..."
            Start-Sleep -Seconds 2
            $retryCount++
        }
    }

    if ($null -eq $result) {
        throw "Failed to retrieve IP information after $maxRetries attempts."
    }

    return $result
}

try {
    $publicIP = Get-PublicIPAddress
    $result = Get-IPInfo -ip $publicIP

    # Light mode card HTML
    $htmlContent = @"
<div style='border:1px solid #ccc; border-radius:10px; padding:16px; background-color:#ffffff; color:#333333; font-family:Segoe UI, sans-serif; width:100%; max-width:400px; box-shadow:0 2px 8px rgba(0,0,0,0.1);'>
    <h3 style='margin-top:0; color:#0078D4;'>� IP Geolocation Info</h3>
    <div style='margin-bottom:10px;'><strong>$ipLogo IP Address:</strong> $($result.ip)</div>
    <div style='margin-bottom:10px;'><strong>$cityLogo City:</strong> $($result.city)</div>
    <div style='margin-bottom:10px;'><strong>$countryLogo Country:</strong> $($result.country)</div>
</div>
"@

    Ninja-Property-Set ipgeolocation $htmlContent

    Write-Output "HTML card set with geolocation data."

    if ($result.country -eq 'CA' -or $result.country -eq 'US') {
        Write-Host '0'
        exit 0
    } else {
        Write-Host '999'
        exit 999
    }
}
catch {
    Write-Error "An error occurred: $_"
    Write-Host '999'
    exit 999
}
