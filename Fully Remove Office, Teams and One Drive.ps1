# Uninstall Microsoft Office
Write-Host "Uninstalling Microsoft Office..."
Get-WmiObject -Query "SELECT * FROM Win32_Product WHERE Name LIKE '%Microsoft Office%'" | ForEach-Object {
    $_.Uninstall()
}

# Uninstall Microsoft Teams
Write-Host "Uninstalling Microsoft Teams..."
Get-WmiObject -Query "SELECT * FROM Win32_Product WHERE Name LIKE '%Teams%'" | ForEach-Object {
    $_.Uninstall()
}

# Uninstall OneDrive
Write-Host "Uninstalling Microsoft OneDrive..."
$OneDrivePath = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
if (Test-Path $OneDrivePath) {
    Start-Process -FilePath $OneDrivePath -ArgumentList "/uninstall" -Wait
    Write-Host "OneDrive uninstalled."
} else {
    Write-Host "OneDrive setup file not found."
}

# Remove residual files
Write-Host "Removing residual files..."
$FoldersToRemove = @(
    "$env:PROGRAMFILES\Microsoft Office",
    "$env:PROGRAMFILES(X86)\Microsoft Office",
    "$env:LOCALAPPDATA\Microsoft\Office",
    "$env:APPDATA\Microsoft\Office",
    "$env:PROGRAMDATA\Microsoft\Office",
    "$env:LOCALAPPDATA\Microsoft\Teams",
    "$env:APPDATA\Microsoft\Teams",
    "$env:PROGRAMDATA\Microsoft\Teams",
    "$env:LOCALAPPDATA\Microsoft\OneDrive",
    "$env:APPDATA\Microsoft\OneDrive",
    "$env:PROGRAMDATA\Microsoft OneDrive"
)

foreach ($folder in $FoldersToRemove) {
    if (Test-Path $folder) {
        Remove-Item -Recurse -Force -Path $folder
        Write-Host "Deleted: $folder"
    } else {
        Write-Host "Folder not found: $folder"
    }
}

# Clean up registry entries
Write-Host "Cleaning up registry entries..."
$RegistryPaths = @(
    "HKCU:\Software\Microsoft\Office",
    "HKLM:\Software\Microsoft\Office",
    "HKLM:\Software\Wow6432Node\Microsoft\Office",
    "HKCU:\Software\Microsoft\Teams",
    "HKLM:\Software\Microsoft\Teams",
    "HKCU:\Software\Microsoft\OneDrive",
    "HKLM:\Software\Microsoft\OneDrive"
)

foreach ($regPath in $RegistryPaths) {
    if (Test-Path $regPath) {
        Remove-Item -Recurse -Force -Path $regPath
        Write-Host "Deleted registry path: $regPath"
    } else {
        Write-Host "Registry path not found: $regPath"
    }
}

Write-Host "Microsoft Office, Teams, and OneDrive cleanup completed."