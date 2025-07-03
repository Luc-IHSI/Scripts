# Define the path to the registry key
$registryPath = "HKLM:\System\CurrentControlSet\Control\Network"
 
# Define the name of the new key
$newKeyName = "NewNetworkWindowOff"
 
# Check if the key already exists
if (-not (Test-Path "$registryPath\$newKeyName")) {
    # Create the new registry key
    New-Item -Path $registryPath -Name $newKeyName -Force
    Write-Output "Registry key '$newKeyName' has been created successfully at '$registryPath'."
} else {
    Write-Output "Registry key '$newKeyName' already exists at '$registryPath'."
}