New-OSDCloudTemplate 
Set-OSDCloudWorkspace D:\OSDCloudProduction
Get-OSDCloudWorkspace

New-OSDCloudWorkspace -WorkspacePath D:\OSDCloudProduction

Get-Module
Get-Process
Stop-Process -Name pwsh


Install-Module -Name OSD

Update-Module OSD
Import-Module OSD -Force

Edit-OSDCloudWinPE -CloudDriver *
Edit-OSDCloudWinPE

Import-OSDCloudWinPEDriverMDT -Driver *