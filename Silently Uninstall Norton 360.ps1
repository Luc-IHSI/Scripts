# Define the Norton process names
$nortonProcesses = @("NortonSecurity.exe", "Norton360.exe", "Norton.exe")

# Kill Norton processes
foreach ($process in $nortonProcesses) {
    Get-Process -Name $process -ErrorAction SilentlyContinue | Stop-Process -Force
}

# Define the URL and the destination path
$url = "https://norton.com/nrnr"
$destination = "$env:PUBLIC\Downloads\NRnR.exe"

# Download the Norton Remove and Reinstall Tool
Invoke-WebRequest -Uri $url -OutFile $destination

# Run the tool silently
Start-Process -FilePath $destination -ArgumentList "/silent /norestart" -NoNewWindow -Wait
