$printerNamePattern = "Brother HL-3170*" #make sure to keep the * at the end of the printer name
$newPrinterName = "Brother HL-3170"

$printer = Get-Printer | Where-Object { $_.Name -like $printerNamePattern }
if ($printer) {
    Rename-Printer -Name $printer.Name -NewName $newPrinterName
}