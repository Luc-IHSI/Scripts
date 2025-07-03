# Set region and location to English (Canada)
$region = "en-CA"
$location = "Canada"

# Change region setting
Set-WinUILanguageOverride -Language $region
Set-WinUserLanguageList -LanguageList $region -Force
Set-WinSystemLocale -SystemLocale $region

# Change location setting
Set-WinHomeLocation -GeoID 39  # GeoID 39 corresponds to Canada

# Set date and time formats for current user
$shortDate = "dd/MM/yyyy"
$longDate = "ddd,MMMM dd, yyyy"
Set-Culture $region
Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name "sShortDate" -Value $shortDate
Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name "sLongDate" -Value $longDate

# Export current user registry settings to a file
$exportPath = "$env:TEMP\International.reg"
reg export "HKCU\Control Panel\International" $exportPath

# Import registry settings to default user profile
Start-Process -FilePath "reg.exe" -ArgumentList "import", "$exportPath" -Wait -NoNewWindow

# Clean up
Remove-Item $exportPath
