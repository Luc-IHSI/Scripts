# Ensure the script runs as administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Restarting script with administrator privileges..."
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Kill all TeamViewer processes
Get-Process -Name "TeamViewer" -ErrorAction SilentlyContinue | Stop-Process -Force

# Uninstall TeamViewer silently
$teamViewerUninstallPath = "C:\Program Files (x86)\TeamViewer\uninstall.exe"
if (Test-Path $teamViewerUninstallPath) {
    Start-Process -FilePath $teamViewerUninstallPath -ArgumentList "/S" -Wait
}

# Remove leftover files and folders
$foldersToDelete = @(
    "C:\Program Files (x86)\TeamViewer",
    "C:\ProgramData\TeamViewer",
    "$env:APPDATA\TeamViewer",
    "$env:LOCALAPPDATA\TeamViewer"
)
foreach ($folder in $foldersToDelete) {
    if (Test-Path $folder) {
        Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Remove leftover registry entries
$registryPathsToDelete = @(
    "HKLM:\SOFTWARE\TeamViewer",
    "HKLM:\SOFTWARE\WOW6432Node\TeamViewer",
    "HKCU:\SOFTWARE\TeamViewer"
)
foreach ($regPath in $registryPathsToDelete) {
    if (Test-Path $regPath) {
        Remove-Item -Path $regPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Notify the user of completion
Write-Host "TeamViewer has been completely removed from the system."