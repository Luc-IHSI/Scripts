#########################################################
# Upgrade to Windows 10
#
## Directory Path
$directoryPath = "C:\temp\Win10Upgrade"

## Check if directory exists
if (Test-Path -Path $directoryPath) {
    Remove-Item -Path $directoryPath -Recurse -Force
}

## Create Directory
New-Item -Path $directoryPath -ItemType Directory

## Get Variables
$url = "https://go.microsoft.com/fwlink/?LinkID=799445"
$outputfile = "$directoryPath\Windows10upgrade.exe"

## Download File
(New-Object Net.WebClient).DownloadFile($url, $outputfile)

## Start Windows 10 Upgrade
& $outputfile /quietinstall /skipeula /auto upgrade /dynamicupdate enable
