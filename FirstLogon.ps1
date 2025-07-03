$scripts = @(
    {
        Set-ItemProperty -LiteralPath 'Registry::HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name 'AutoLogonCount' -Type 'DWord' -Force -Value 0;
    },
    {
        cmd.exe /c "rmdir C:\\Windows.old";
    }
);

& {
    [float] $complete = 0;
    [float] $increment = 100 / $scripts.Count;
    foreach( $script in $scripts ) {
        Write-Progress -Activity 'Running first logon scripts.' -PercentComplete $complete;
        & $script;
        $complete += $increment;
    }
}