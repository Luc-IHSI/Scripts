#-----------------------------------------------------------
#DESCRIPTION
#-----------------------------------------------------------
<#

This script will deploy the Microsoft Windows App for
universal remote access platforms.

#>
#-----------------------------------------------------------
#STATIC VARIABLES
#-----------------------------------------------------------

$fWorking = "C:\[CUSTOM_DIR]"
$arch_codes = [PSCustomObject]@{
    32 = 2262634
    64 = 2262633
}
$sys_arch = (Get-CimInstance Win32_operatingsystem).OSArchitecture
$app_lnkName = "Cloud Remote App"

#-----------------------------------------------------------
#ACTIVE CODE
#-----------------------------------------------------------

# Check for Windows App
$app_stat = Get-AppxPackage -AllUsers | Where-Object Name -like "MicrosoftCorporationII.Windows365"
$app_stat
if ($app_stat.Status -eq "Ok"){
    Write-Host "The Windows App is already installed on this endpoint."
    Write-Host "Checking for public desktop shortcut."
    $check_lnk = Test-Path -Path "C:\Users\Public\Desktop\$($app_lnkName).lnk"
    if ($check_lnk){
        Write-Host "The Windows App shortcut is already on the Public Desktop"
        Write-Host "No further action will be taken."
    } else {
        Write-Host "The Windows App shortcut is missing from the Public Desktop"
        Write-Host "Establishing the shortcut now."
        $s=(New-Object -COM WScript.Shell).CreateShortcut("C:\Users\Public\Desktop\$($app_lnkName).lnk");$s.TargetPath="$($app_stat.InstallLocation)\Windows365.exe";$s.Save()
    }
    Write-Host "*****SCRIPT END*****"
    Exit
} else {
    Write-Host "The Windows App was not found on this endpoint."
}

# Chech CPU archetecture
if ([string]$sys_arch -eq "64-bit"){
    $url = "https://go.microsoft.com/fwlink/?linkid=$($arch_codes.64)"
} else {
    $url = "https://go.microsoft.com/fwlink/?linkid=$($arch_codes.32)"
}

# Install Windows App
Write-Host "Installing Windows App now."
Invoke-WebRequest $url -OutFile "$fWorking\WindowsApp.msix"
Start-Sleep 2
DISM /Online /Add-ProvisionedAppxPackage /PackagePath:"$fWorking\WindowsApp.msix" /SkipLicense
Start-Sleep 2

# Re-Check for Windows App
$app_stat = ""
$app_stat = Get-AppxPackage -AllUsers | Where-Object Name -like "MicrosoftCorporationII.Windows365"
if ($app_stat.Status -eq "Ok"){
    Write-Host "The Windows App is was installed successfully."
    Remove-Item -Path "$fWorking\WindowsApp.msix" -Force
    Start-Sleep 2
    $check_lnk = Test-Path -Path "C:\Users\Public\Desktop\$($app_lnkName).lnk"
    if ($check_lnk){
        Write-Host "The Windows App shortcut is already on the Public Desktop"
        Write-Host "No further action will be taken."
    } else {
        Write-Host "The Windows App shortcut is missing from the Public Desktop"
        Write-Host "Establishing the shortcut now."
        $s=(New-Object -COM WScript.Shell).CreateShortcut("C:\Users\Public\Desktop\$($app_lnkName).lnk");$s.TargetPath="$($app_stat.InstallLocation)\Windows365.exe";$s.Save()
    }
} else {
    Write-Host "The Windows App failed to install."
    Write-Host "Please manually install this application"
}
Write-Host "*****SCRIPT END*****"