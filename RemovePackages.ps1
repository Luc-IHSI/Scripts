$packages = @(
    'Microsoft.Microsoft3DViewer',
    'Microsoft.BingSearch',
    'Microsoft.Office.OneNote',
    'Microsoft.XboxGamingOverlay'
);

foreach ($package in $packages) {
    Write-Output "Removing $package...";
    Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $package } | Remove-AppxProvisionedPackage -Online -AllUsers;
}
