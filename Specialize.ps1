$scripts = @(
    {
        Remove-Item -LiteralPath 'C:\Windows\System32\OneDriveSetup.exe', 'C:\Windows\SysWOW64\OneDriveSetup.exe' -ErrorAction 'SilentlyContinue';
    },
    {
        reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v LongPathsEnabled /t REG_DWORD /d 1 /f;
    },
    {
        Set-ExecutionPolicy -Scope 'LocalMachine' -ExecutionPolicy 'RemoteSigned' -Force;
    }
);

foreach ($script in $scripts) {
    Write-Output "Running script...";
    & $script;
}
