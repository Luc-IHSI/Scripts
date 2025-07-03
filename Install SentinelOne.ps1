# Set the hostname of your server here.
$Server = "usea1-ninjaone"

# Set the site token for the SentinelOne site here
$siteToken = Ninja-Property-Docs-Get 'Software' SENTINELONE productKey

# Set your API Token here
#$ApiToken = Ninja-Property-Docs-Get 'Software' SENTINELONE apiToken
$ApiToken = 'eyJraWQiOiJ1cy1lYXN0LTEtcHJvZC0wIiwiYWxnIjoiRVMyNTYifQ.eyJzdWIiOiJzZXJ2aWNldXNlci1lODJiZDc4MS0xNzc0LTRiOWMtYTAxYy00ZjcxMzA3NzQ4ODZAbWdtdC03Mjk4Ny5zZW50aW5lbG9uZS5uZXQiLCJpc3MiOiJhdXRobi11cy1lYXN0LTEtcHJvZCIsImRlcGxveW1lbnRfaWQiOiI3Mjk4NyIsInR5cGUiOiJ1c2VyIiwiZXhwIjoxODEwMjE0NTk2LCJpYXQiOjE3NDcxNDMwMDYsImp0aSI6ImYxY2QzNmM4LWYzOTctNGMyMS1iMGYzLTNlMmYzYmFhZTg5OCJ9.9ka7FwYSofW0bQNkTBFW3SRw0YIeNX6FN370Ei7O6u2yLGm4LG8HLZ425u66SQioYkGWvrqZjBx4LluHAOB0RQ'

#############################
#region RMMTemplate

$Global:nl = [System.Environment]::NewLine
$Global:ErrorCount = 0
$global:Output = '' 

#######

#######
function RMM-Msg
{
  param ($Message)
  $global:Output += " $Message"+$Global:nl
}

#######
function RMM-Error
{
  param ($Message)
  $Global:ErrorCount += 1
  $global:Output += "!$Message"+$Global:nl
}

#######
function RMM-Exit
{  
  $Message = '----------'+$Global:nl+"ErrorCount : $Global:ErrorCount"
  $global:Output += $Message
  Ninja-Property-Set antivirusInstallationOutput $global:Output
  Write-Host -Object "$global:Output"
  Exit(0)
}

#endregion 
############################# 

# Force TLS 1.2. Not always necessary but Windows Version below 1903 will default to TLS 1.1 or worse and fail.
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

# Set headers
$headers = @{
'Authorization'= "ApiToken $ApiToken"
'Content-Type'= "application/json"
}

function Get-TimeStamp() {
    return Get-Date -UFormat "%Y-%m-%d %H:%M:%S"
}

if (($null -eq $siteToken) -or ($siteToken.Length -eq 0)) {
    RMM-Error "$(Get-Timestamp) SentinelOne Site Token is empty in your documentation"
    RMM-Exit
}

if (($null -eq $ApiToken) -or ($ApiToken.Length -eq 0)) {
    RMM-Error "$(Get-Timestamp) SentinelOne API Token is empty in your documentation"
    RMM-Exit
}

if (($null -eq $Server) -or ($Server.Length -eq 0)) {
    RMM-Error "$(Get-Timestamp) Server parameter is not specified"
    RMM-Exit
}

# Check if software is installed. If key is present, terminate script
RMM-Msg "$(Get-Timestamp) Checking if SentinelOne is installed..."

$64bit = if ([System.IntPtr]::Size -eq 8) { $true } else { $false }
$RegKeys = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\')
if ($true -eq $64bit) { $RegKeys += 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\' }
$Apps = @($RegKeys | Get-ChildItem | Get-ItemProperty | Where-Object { $_.DisplayName -like "*SentinelOne*" })
if ($Apps.Count -gt 0) {
    RMM-Error "$(Get-Timestamp) SentinelOne is already installed"
    RMM-Exit
}

# Download
RMM-Msg "$(Get-Timestamp) SentinelOne is not installed"

# Force TLS 1.2. Not always necessary but Windows Version below 1903 will default to TLS 1.1 or worse and fail.
RMM-Msg "$(Get-Timestamp) Forcing TLS 1.2"
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

# Wait between 1-1800 seconds to not overwhelm the API (UNCOMMENT TO ENABLE RANDOM WAIT)
RMM-Msg "$(Get-Timestamp) Starting Wait"
start-sleep -Seconds (1..1800 | get-random)
RMM-Msg "$(Get-Timestamp) Ending Wait"

# Get the details on the latest General Availability MSI installer available from your Sentinel One server instance.
try {
 $response = Invoke-RestMethod -Uri "https://$Server.sentinelone.net/web/api/v2.1/update/agent/packages?fileExtension=.msi&limit=2&osTypes=windows&sortBy=majorVersion&sortOrder=desc&status=ga" -Method 'GET' -Headers $headers
 $payload = $response.data | Where {
    $_.osArch -eq "64 bit"
 }
} catch {
RMM-Error "$(Get-Timestamp) S1 Error; Unable to complete the API call."
RMM-Error $_
RMM-Exit
}

# Set the filename and location for the downloaded installer
$file = "C:\SentinelAgent_windows.msi"

# Download the latest 64-Bit MSI Installer.
RMM-Msg "$(Get-Timestamp) Downloading last available SentinelOne package ..."
try {
Invoke-WebRequest -Uri $payload.link -Outfile $file -Headers $headers -UseBasicParsing
} Catch {
RMM-Error "$(Get-Timestamp) S1 Error; Unable to download the installer."
RMM-Error $_
RMM-Exit
}
RMM-Msg "$(Get-Timestamp) Downloaded"

# Silently install the agent and set the site token. No restart.
if ($file) {
    RMM-Msg "$(Get-Timestamp) Starting the installation of SentinelOne..."
    Start-Process msiexec.exe -Wait -ArgumentList "/i $file SITE_TOKEN=$siteToken /q /quiet /norestart"
    
    RMM-Msg "$(Get-Timestamp) Installed"
    RMM-Msg "$(Get-Timestamp) Cleaning up temp file..."

    # Cleanup
    if (Test-Path -PathType Leaf -Path $file) {
        Remove-Item $file
    }

    RMM-Msg "$(Get-Timestamp) Finished!"
    
    RMM-Exit
} else {
    RMM-Error "$(Get-Timestamp) Could not find $file; Did it fail to download?"
    RMM-Exit
}