$capabilities = @(
    'App.StepsRecorder',
    'Media.WindowsMediaPlayer'
);

foreach ($capability in $capabilities) {
    Write-Output "Removing $capability...";
    Remove-WindowsCapability -Online -Name $capability;
}
