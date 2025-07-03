# Remove Konica Printers silently
Get-Printer | Where-Object { $_.Name -like "*Konica*" } | ForEach-Object {
    Remove-Printer -Name $_.Name -Confirm:$false
}

# Remove Konica Printer Drivers silently
Get-PrinterDriver | Where-Object { $_.Name -like "*Konica*" } | ForEach-Object {
    Remove-PrinterDriver -Name $_.Name -Force
}

# Remove Konica Printer Ports silently
Get-PrinterPort | Where-Object { $_.Name -like "*Konica*" } | ForEach-Object {
    Remove-PrinterPort -Name $_.Name -Confirm:$false
}

# Remove Konica Printer Software silently
Get-WmiObject -Query "SELECT * FROM Win32_Product WHERE Name LIKE '%Konica%'" | ForEach-Object {
    $_.Uninstall() | Out-Null
}
