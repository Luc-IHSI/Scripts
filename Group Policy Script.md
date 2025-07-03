# Import the Group Policy module
Import-Module GroupPolicy

# Variables
$GpoName = "ACCI PC Customizations GPO"
$OuName = "OU=AADDC,DC=aadds,DC=atlanticcontractinginc,DC=com"

# Step 1: Create the GPO
Write-Host "Creating GPO: $GpoName"
$Gpo = New-GPO -Name $GpoName -Domain "aadds.atlanticcontractinginc.com"

# Step 2: File Explorer Settings
Write-Host "Configuring File Explorer settings..."
Set-GPRegistryValue -Name $GpoName -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -ValueName "NoRecentDocsHistory" -Type DWORD -Value 1  # Turn off recent search entries
Set-GPRegistryValue -Name $GpoName -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -ValueName "Hidden" -Type DWORD -Value 1  # Show hidden files
Set-GPRegistryValue -Name $GpoName -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -ValueName "HideFileExt" -Type DWORD -Value 0  # Disable hiding file extensions
Set-GPRegistryValue -Name $GpoName -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -ValueName "LaunchTo" -Type DWORD -Value 1  # Launch File Explorer to "This PC"

# Step 3: Start Menu and Taskbar Settings
Write-Host "Configuring Start Menu and Taskbar settings..."
Set-GPRegistryValue -Name $GpoName -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -ValueName "NoRecentDocsMenu" -Type DWORD -Value 1  # Remove Recently opened items
Set-GPRegistryValue -Name $GpoName -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -ValueName "NoStartMenuMFUprogramsList" -Type DWORD -Value 1  # Remove "Recently added"
Set-GPRegistryValue -Name $GpoName -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -ValueName "HideBalloonTips" -Type DWORD -Value 1  # Turn off notifications
Set-GPRegistryValue -Name $GpoName -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -ValueName "TaskbarSmallIcons" -Type DWORD -Value 0  # Disable small taskbar buttons
Set-GPRegistryValue -Name $GpoName -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -ValueName "ShowTaskViewButton" -Type DWORD -Value 0  # Hide Task View button

# Step 4: Regional Settings
Write-Host "Configuring Regional Options..."
Set-GPPrefRegistryValue -Name $GpoName -Context User -Key "HKCU\Control Panel\International" -ValueName "sShortDate" -Type String -Value "dd/MM/yyyy"
Set-GPPrefRegistryValue -Name $GpoName -Context User -Key "HKCU\Control Panel\International" -ValueName "sLongDate" -Type String -Value "dddd, MMMM dd, yyyy"
Set-GPPrefRegistryValue -Name $GpoName -Context User -Key "HKCU\Control Panel\International" -ValueName "sShortTime" -Type String -Value "h:mm tt"
Set-GPPrefRegistryValue -Name $GpoName -Context User -Key "HKCU\Control Panel\International" -ValueName "sLongTime" -Type String -Value "h:mm:ss tt"

# Step 5: Power Settings
Write-Host "Configuring Power Settings..."
Set-GPRegistryValue -Name $GpoName -Key "HKLM\SOFTWARE\Policies\Microsoft\Power\PowerSettings\dc\ACSettingIndex" -ValueName "SleepTimeout" -Type DWORD -Value 0  # Disable sleep
Set-GPRegistryValue -Name $GpoName -Key "HKLM\SOFTWARE\Policies\Microsoft\Power\PowerSettings\ac\ACSettingIndex" -ValueName "SleepTimeout" -Type DWORD -Value 0  # Disable sleep

# Step 6: Content Delivery Manager Settings
Write-Host "Configuring Content Delivery Manager settings..."
Set-GPRegistryValue -Name $GpoName -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -ValueName "SilentInstalledAppsEnabled" -Type DWORD -Value 0  # Turn off consumer experiences
Set-GPRegistryValue -Name $GpoName -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -ValueName "SystemPaneSuggestionsEnabled" -Type DWORD -Value 0  # Turn off tips

# Step 7: Game Bar and Game Mode Settings
Write-Host "Disabling Game Bar and Game Mode..."
Set-GPRegistryValue -Name $GpoName -Key "HKCU\Software\Microsoft\GameBar" -ValueName "AllowAutoGameMode" -Type DWORD -Value 0  # Disable Game Mode
Set-GPRegistryValue -Name $GpoName -Key "HKCU\Software\Microsoft\GameBar" -ValueName "ShowStartupPanel" -Type DWORD -Value 0  # Disable Game Bar

# Step 8: UAC Settings
Write-Host "Configuring UAC settings..."
Set-GPRegistryValue -Name $GpoName -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "PromptOnSecureDesktop" -Type DWORD -Value 0  # Disable secure desktop for elevation



# Configure Taskbar Alignment (Align to Left)
Write-Host "Configuring Taskbar Alignment (Align to Left)..."
Set-GPPrefRegistryValue -Name $GpoName -Context User -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -ValueName "TaskbarAl" -Type DWORD -Value 0 -Action Create

# Configure Search Icon Only
Write-Host "Configuring Taskbar Search Icon Only..."
Set-GPPrefRegistryValue -Name $GpoName -Context User -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" -ValueName "SearchboxTaskbarMode" -Type DWORD -Value 1 -Action Create

# Disable Widgets on Taskbar
Write-Host "Disabling Widgets on Taskbar..."
Set-GPPrefRegistryValue -Name $GpoName -Context User -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -ValueName "TaskbarDa" -Type DWORD -Value 0 -Action Create


Write-Host "GPO Configuration Completed!"
