$currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Start-Process powershell -Verb runAs
    exit
}

$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
Clear-Content -Path $hostsPath
$newEntry = ""
$newEntry1 = "`n" #leave `n to create a new line item

(Get-Content $hostsPath) + $newEntry + $newEntry1 | Set-Content $hostsPath -Force

Get-Content $hostsPath
