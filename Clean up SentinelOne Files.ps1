# Run as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Please run this script as Administrator!"
    exit
}

Write-Host "Starting SentinelOne cleanup process..." -ForegroundColor Green

# Stop SentinelOne services if they exist
$services = @("SentinelAgent", "SentinelHelperService", "SentinelStaticEngine", "LogProcessorService")
foreach ($service in $services) {
    if (Get-Service -Name $service -ErrorAction SilentlyContinue) {
        Write-Host "Stopping $service service..." -ForegroundColor Yellow
        Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
        Write-Host "Disabling $service service..." -ForegroundColor Yellow
        Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
    }
}

# Try to uninstall using MSI product code if available
$uninstallKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

foreach ($key in $uninstallKeys) {
    if (Test-Path $key) {
        $sentinelUninstall = Get-ChildItem $key | Get-ItemProperty | Where-Object { $_.DisplayName -like "*SentinelOne*" }
        if ($sentinelUninstall) {
            Write-Host "Attempting to uninstall SentinelOne using MSI..." -ForegroundColor Yellow
            $productCode = $sentinelUninstall.PSChildName
            Start-Process "msiexec.exe" -ArgumentList "/x $productCode /qn" -Wait
        }
    }
}

# Remove SentinelOne folders
$folders = @(
    "${env:ProgramFiles}\SentinelOne",
    "${env:ProgramFiles(x86)}\SentinelOne",
    "${env:ProgramData}\Sentinel",
    "${env:ProgramData}\SentinelOne"
)

foreach ($folder in $folders) {
    if (Test-Path $folder) {
        Write-Host "Removing folder: $folder" -ForegroundColor Yellow
        Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Clean registry entries
$registryPaths = @(
    "HKLM:\SOFTWARE\SentinelOne",
    "HKLM:\SOFTWARE\WOW6432Node\SentinelOne",
    "HKLM:\SYSTEM\CurrentControlSet\Services\SentinelAgent",
    "HKLM:\SYSTEM\CurrentControlSet\Services\SentinelHelperService",
    "HKLM:\SYSTEM\CurrentControlSet\Services\SentinelStaticEngine",
    "HKLM:\SYSTEM\CurrentControlSet\Services\LogProcessorService"
)

foreach ($path in $registryPaths) {
    if (Test-Path $path) {
        Write-Host "Removing registry key: $path" -ForegroundColor Yellow
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Remove SentinelOne driver files
$driverFiles = Get-ChildItem "${env:SystemRoot}\System32\drivers" -Filter "Sentinel*.sys" -ErrorAction SilentlyContinue
foreach ($file in $driverFiles) {
    Write-Host "Removing driver file: $($file.FullName)" -ForegroundColor Yellow
    Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
}

# Clean temporary files
if (Test-Path "${env:TEMP}\SentinelOne") {
    Write-Host "Removing temporary SentinelOne files..." -ForegroundColor Yellow
    Remove-Item -Path "${env:TEMP}\SentinelOne" -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "SentinelOne cleanup completed. Please restart your computer before attempting reinstallation." -ForegroundColor Green