$regPaths = @(
    "HKLM:\SOFTWARE\Policies\Microsoft\Edge",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement"
)
$regValues = @{
    "HKLM:\SOFTWARE\Policies\Microsoft\Edge" = @{ "HideFirstRunExperience" = 1 }
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement" = @{ "ShowRecommendationsEnabled" = 0 }
}
 
# Create registry paths and set values
foreach ($path in $regPaths) {
    if (-not (Test-Path $path)) {
        New-Item -Path $path -Force
    }
 
    foreach ($key in $regValues[$path].Keys) {
        Set-ItemProperty -Path $path -Name $key -Value $regValues[$path][$key]
    }
}
 
Write-Output "Microsoft Edge First Run Experience and recommendations have been disabled."
