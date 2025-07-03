$json = @{
    pinnedList = @(
        @{ desktopAppLink = "%ALLUSERSPROFILE%\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk" },
        @{ desktopAppLink = "%APPDATA%\Microsoft\Windows\Start Menu\Programs\File Explorer.lnk" }
    )
} | ConvertTo-Json -Depth 10;

$key = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Start';
New-Item -Path $key -Force;
Set-ItemProperty -Path $key -Name 'ConfigureStartPins' -Value $json -Type String;
