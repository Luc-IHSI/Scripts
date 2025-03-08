# Sage 50 Cleanup Script
# Run as administrator for full access to registry and system folders

# Display script header
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "        Sage 50 Complete Cleanup Utility" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "This script will remove Sage 50 remnants after uninstallation."
Write-Host "Please ensure Sage 50 has been uninstalled before running this script."
Write-Host ""

# Function to safely remove registry keys
function Remove-RegistryKey {
    param (
        [string]$Path
    )
    
    if (Test-Path $Path) {
        try {
            Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
            Write-Host "Removed registry key: $Path" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to remove registry key: $Path" -ForegroundColor Yellow
            Write-Host "Error: $_" -ForegroundColor Red
        }
    }
    else {
        Write-Host "Registry key not found: $Path" -ForegroundColor Gray
    }
}

# Function to safely remove folders
function Remove-FolderSafely {
    param (
        [string]$Path
    )
    
    if (Test-Path $Path) {
        try {
            Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
            Write-Host "Removed folder: $Path" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to remove folder: $Path" -ForegroundColor Yellow
            Write-Host "Error: $_" -ForegroundColor Red
        }
    }
    else {
        Write-Host "Folder not found: $Path" -ForegroundColor Gray
    }
}

# Step 1: Clean up Program Files directories
Write-Host "Step 1: Removing Sage folders from Program Files..." -ForegroundColor Cyan
$programFilesPaths = @(
    "${env:ProgramFiles}\Sage",
    "${env:ProgramFiles}\Sage 50*",
    "${env:ProgramFiles(x86)}\Sage",
    "${env:ProgramFiles(x86)}\Sage 50*"
)

foreach ($path in $programFilesPaths) {
    Get-Item -Path $path -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-FolderSafely -Path $_.FullName
    }
}

# Step 2: Clean up user AppData directories
Write-Host "Step 2: Removing Sage data from AppData folders..." -ForegroundColor Cyan
$appDataPaths = @(
    "$env:LOCALAPPDATA\Sage",
    "$env:APPDATA\Sage",
    "$env:USERPROFILE\AppData\LocalLow\Sage",
    "$env:ALLUSERSPROFILE\Sage"
)

foreach ($path in $appDataPaths) {
    Remove-FolderSafely -Path $path
}

# Step 3: Clean up Registry
Write-Host "Step 3: Cleaning up Registry entries..." -ForegroundColor Cyan
$registryPaths = @(
    "HKCU:\Software\Sage",
    "HKLM:\Software\Sage",
    "HKLM:\Software\WOW6432Node\Sage",
    "HKCR:\Simply Accounting Data File",
    "HKCR:\.sai"
)

foreach ($path in $registryPaths) {
    Remove-RegistryKey -Path $path
}

# Step 4: Remove file associations
Write-Host "Step 4: Removing file associations..." -ForegroundColor Cyan
try {
    cmd /c "assoc .sai=" | Out-Null
    Write-Host "Removed .sai file association" -ForegroundColor Green
}
catch {
    Write-Host "Failed to remove .sai file association" -ForegroundColor Yellow
}

# Step 5: Check for Sage services
Write-Host "Step 5: Checking for remaining Sage services..." -ForegroundColor Cyan
$sageServices = Get-Service | Where-Object { $_.DisplayName -like "*Sage*" }
if ($sageServices) {
    Write-Host "Found Sage services that need to be removed:" -ForegroundColor Yellow
    foreach ($service in $sageServices) {
        Write-Host "  - $($service.DisplayName) [$($service.Name)]" -ForegroundColor Yellow
        Write-Host "    To remove manually, use SC DELETE $($service.Name)" -ForegroundColor Yellow
    }
}
else {
    Write-Host "No Sage services found." -ForegroundColor Green
}

# Step 6: Check for Sage scheduled tasks
Write-Host "Step 6: Checking for Sage scheduled tasks..." -ForegroundColor Cyan
$sageTasks = Get-ScheduledTask | Where-Object { $_.TaskName -like "*Sage*" -or $_.TaskPath -like "*Sage*" } -ErrorAction SilentlyContinue
if ($sageTasks) {
    Write-Host "Found Sage scheduled tasks:" -ForegroundColor Yellow
    foreach ($task in $sageTasks) {
        Write-Host "  - $($task.TaskName)" -ForegroundColor Yellow
        try {
            Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction Stop
            Write-Host "    Removed task: $($task.TaskName)" -ForegroundColor Green
        }
        catch {
            Write-Host "    Failed to remove task. Remove manually from Task Scheduler." -ForegroundColor Red
        }
    }
}
else {
    Write-Host "No Sage scheduled tasks found." -ForegroundColor Green
}

# Step 7: Clean temporary files that might contain Sage data
Write-Host "Step 7: Cleaning temporary files..." -ForegroundColor Cyan
$tempPaths = @(
    "$env:TEMP\Sage*"
)

foreach ($path in $tempPaths) {
    Get-Item -Path $path -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-FolderSafely -Path $_.FullName
    }
}

# Final report
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "Sage 50 cleanup completed!" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "It's recommended to restart your computer before reinstalling Sage or any other accounting software."
Write-Host ""
Write-Host "For any remaining issues, you may need to manually check:"
Write-Host "1. Documents folders for any remaining Sage data files"
Write-Host "2. Start Menu for remaining Sage shortcuts"
Write-Host "3. Desktop for any remaining Sage shortcuts"
Write-Host "====================================================" -ForegroundColor Cyan