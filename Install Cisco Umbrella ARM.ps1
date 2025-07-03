# The files are hosted here: https://github.com/Luc-IHSI/CiscoUmbrella

# Define the GitHub base URL and Org Files base URL
$githubBaseUrl = "https://raw.githubusercontent.com/Luc-IHSI/CiscoUmbrella/main/" # Ensure trailing slash
$orgFilesBaseUrlBase = "https://raw.githubusercontent.com/Luc-IHSI/CiscoUmbrella/main/Org%20Files" # Separate Org Files base URL

# Define the company name (retrieve dynamically using Ninja or set manually)
$companyName = Ninja-Property-Docs-Get 'CiscoUmbrella' 'CompanyName'

# Validate the company name
if (-not $companyName) {
    Write-Error "Company name is not set. Please ensure it is defined in the Ninja documentation."
    exit 1
}

# Update the Org Files base URL for the specific company
$orgFilesBaseUrl = "$orgFilesBaseUrlBase/$companyName"

$filesToDownload = @(
    "cisco-secure-client-win-arm64-5.1.9.113-core-vpn-predeploy-k9.msi",
    "cisco-secure-client-win-arm64-5.1.9.113-umbrella-predeploy-k9.msi",
    "cisco-secure-client-win-arm64-5.1.9.113-dart-predeploy-k9.msi",
    "OrgInfo.json"
)

# Define the local download directory
$downloadDir = "$env:TEMP\CiscoUmbrella"

# Remove existing files in the download directory if they exist
if (Test-Path -Path $downloadDir) {
    Write-Host "Removing existing files in $downloadDir..."
    Remove-Item -Path $downloadDir -Recurse -Force
    Write-Host "Existing files removed."
}

# Recreate the download directory
New-Item -ItemType Directory -Path $downloadDir | Out-Null

# Download each file (update URL for OrgInfo.json)
foreach ($file in $filesToDownload) {
    if ($file -eq "OrgInfo.json") {
        $url = "$orgFilesBaseUrl/$file" # Ensure single slash
    } else {
        $url = "$githubBaseUrl$file"
    }
    $destination = Join-Path -Path $downloadDir -ChildPath $file
    Write-Host "Downloading $file from $url..."
    try {
        Invoke-WebRequest -Uri $url -OutFile $destination -ErrorAction Stop
    } catch {
        Write-Error "Failed to download $file from $url. Error: $_"
        exit 1
    }
}

# Define the OrgInfo.json file path
$org_file = "$env:PROGRAMDATA\Cisco\Cisco Secure Client\Umbrella\OrgInfo.json"

# Download OrgInfo.json and copy it to the required location
$org_file_dir = Split-Path -Path $org_file -Parent
if (-not (Test-Path -Path $org_file_dir)) {
    Write-Host "Creating directory for OrgInfo.json: $org_file_dir"
    New-Item -ItemType Directory -Path $org_file_dir -Force | Out-Null
}
$org_file_source = Join-Path -Path $downloadDir -ChildPath "OrgInfo.json"
Copy-Item -Path $org_file_source -Destination $org_file -Force

# Copy the OrgInfo.json file to the installation directory (if required)
$installDir = "$env:PROGRAMFILES\Cisco\Cisco Secure Client\Umbrella"
if (-not (Test-Path -Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir | Out-Null
}
Copy-Item -Path $org_file -Destination $installDir -Force
Write-Host "OrgInfo.json file copied to $installDir."

msiexec /i "$downloadDir\cisco-secure-client-win-arm64-5.1.9.113-core-vpn-predeploy-k9.msi" PRE_DEPLOY_DISABLE_VPN=1 /norestart /passive LOCKDOWN=2  /lvx* vpninstall.log
Start-Sleep -Seconds 60
msiexec /i "$downloadDir\cisco-secure-client-win-arm64-5.1.9.113-umbrella-predeploy-k9.msi"  /norestart /passive LOCKDOWN=2  /lvx* umbrellainstall.log
Start-Sleep -Seconds 60
msiexec /i "$downloadDir\cisco-secure-client-win-arm64-5.1.9.113-dart-predeploy-k9.msi"  /norestart /passive LOCKDOWN=2  /lvx* dartinstall.log


