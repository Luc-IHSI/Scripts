$features = @(
    'MicrosoftWindowsPowerShellV2Root',
    'WindowsMediaPlayer'
);

foreach ($feature in $features) {
    Write-Output "Removing feature $feature...";
    Disable-WindowsOptionalFeature -FeatureName $feature -Online -NoRestart;
}
