#Check Administrator Privilege

    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    $admin=(New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)  

if ($admin -eq $false) {
"Please run the script as Administrator"

Start-Sleep -s 10
}

#Define the API Token
#To automate the script, get the API Token from management, enter it here, and save the script.
$token = "eyJraWQiOiJ1cy1lYXN0LTEtcHJvZC0wIiwiYWxnIjoiRVMyNTYifQ.eyJzdWIiOiJhbGV4QGluaG91c2Utc3VwcG9ydC5jb20iLCJpc3MiOiJhdXRobi11cy1lYXN0LTEtcHJvZCIsImRlcGxveW1lbnRfaWQiOiI3Mjk4NyIsInR5cGUiOiJ1c2VyIiwiZXhwIjoxNzQyNDg2ODYwLCJpYXQiOjE3Mzk4OTQ4NjAsImp0aSI6ImU2YmJhOTcyLTg1N2EtNDBkNS1iODc1LTY5YjAzMWU3NDJiZiJ9.w8t9JwBsDN4vQscwW1tppdaCx1rBI47u9HGX3Z7hVL5tXLyL7b4vvqNJRUERKkQMquuwn8mrgLLfVOMmYnEt2g"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "APIToken $token")
#where $token is your API token. For example, "APIToken abcdefg...."


#Gets Management URL
$config = & 'C:\Program Files\SentinelOne\Sentinel*\SentinelCtl.exe' config | select-string -Pattern "server.mgmtServer"
$mgmt = $config -split ' ' | select -last 1

#Gets passphrase for Endpoint
$uuid = & 'C:\Program Files\SentinelOne\Sentinel*\SentinelCtl.exe' agent_id
$passphrase_url = $mgmt + "/web/api/v2.1/agents/passphrases?uuids="+"$uuid"
$passphrase = (Invoke-RestMethod ("$passphrase_url") -Method 'GET' -Headers $headers).data.passphrase

#Gets the SiteID for diagnostics
$site_url = $mgmt + "/web/api/v2.1/agents?uuids="+"$uuid"
$siteID = (Invoke-RestMethod ("$site_url") -Method 'GET' -Headers $headers).data.siteId

#Start the Uninstallation
Write-Host "Starting Uninstallation Process..." 
Write-Host "This Process may take a while. Please do not close the Window."
& 'C:\Program Files\SentinelOne\Sentinel*\uninstall.exe' /uninstall /norestart /q /k "$passphrase"