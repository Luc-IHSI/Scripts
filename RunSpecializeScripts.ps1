# Define all scripts that should run during the specialize phase
$scripts = @(
    "$env:SystemDrive\Deploy\Scripts\Specialize.ps1",
    "$env:SystemDrive\Deploy\Scripts\DefaultUser.ps1",
    "$env:SystemDrive\Deploy\Scripts\RemovePackages.ps1",
    "$env:SystemDrive\Deploy\Scripts\RemoveCapabilities.ps1",
    "$env:SystemDrive\Deploy\Scripts\RemoveFeatures.ps1",
    "$env:SystemDrive\Deploy\Scripts\SetStartPins.ps1",
    "$env:SystemDrive\Deploy\Scripts\UnlockStartLayout.ps1"
)

# Loop through each script and execute it
foreach ($script in $scripts) {
    if (Test-Path $script) {
        Write-Output "Executing $script..."
        Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$script`"" -Wait -NoNewWindow
    } else {
        Write-Output "Script not found: $script"
    }
}
