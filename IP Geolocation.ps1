# Function to get the public IP address
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

# Function to get IP information
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
    # Get the public IP address
    $publicIP = Get-PublicIPAddress

    # Get the IP information
    $result = Get-IPInfo -ip $publicIP

    # Store the entire location information in the custom field
    $locationInfo = "IP: $($result.ip), City: $($result.city), Region: $($result.region), Country: $($result.country)"
    Ninja-Property-Set ipgeolocation $locationInfo

    Write-Output "Location Information: $locationInfo"

    # Check if the country is CA or US
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