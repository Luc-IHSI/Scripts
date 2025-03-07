# Configure-UserSettings.ps1
# Purpose: Apply customizations to the current logged-in user and system settings
# Author: Claude (Modified)
# Date: 2025-02-18

try {
    #----------------------------------------------------------------------------------
    # USER CONFIGURATIONS
    #----------------------------------------------------------------------------------
    
    # 1. Configure desktop settings
    # Show file extensions
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0 -Type DWord
    
    # Show hidden files
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1 -Type DWord
    
    # 2. Configure Start Menu
    # Hide recently added apps
    $startLayoutPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Start"
    if (-not (Test-Path $startLayoutPath)) {
        New-Item -Path $startLayoutPath -Force | Out-Null
    }
    Set-ItemProperty -Path $startLayoutPath -Name "HideRecentlyAddedApps" -Value 1 -Type DWord
    
    # Network configuration settings
    try {
        # Set default network location to Private
        $networkPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Network\NwCategoryWizard"
        if (-not (Test-Path $networkPath)) {
            New-Item -Path $networkPath -Force | Out-Null
        }
        Set-ItemProperty -Path $networkPath -Name "DefaultCategory" -Value 1 -Type DWord  # 1 = Private, 0 = Public
        
        # Disable automatic setup of network devices
        $deviceInstallPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\NcdAutoSetup\Private"
        if (-not (Test-Path $deviceInstallPath)) {
            New-Item -Path $deviceInstallPath -Force | Out-Null
        }
        Set-ItemProperty -Path $deviceInstallPath -Name "AutoSetup" -Value 0 -Type DWord
        
        # Also set for Public networks
        $deviceInstallPathPublic = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\NcdAutoSetup\Public"
        if (-not (Test-Path $deviceInstallPathPublic)) {
            New-Item -Path $deviceInstallPathPublic -Force | Out-Null
        }
        Set-ItemProperty -Path $deviceInstallPathPublic -Name "AutoSetup" -Value 0 -Type DWord
    } 
    catch {}

    # Disable Game Bar and Game Mode
    try {
        # Disable Game Bar
        $gameDVRPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"
        if (-not (Test-Path $gameDVRPath)) {
            New-Item -Path $gameDVRPath -Force | Out-Null
        }
        Set-ItemProperty -Path $gameDVRPath -Name "AppCaptureEnabled" -Value 0 -Type DWord
        
        # Disable Game Bar shortcuts
        $gameBarPath = "HKCU:\SOFTWARE\Microsoft\GameBar"
        if (-not (Test-Path $gameBarPath)) {
            New-Item -Path $gameBarPath -Force | Out-Null
        }
        Set-ItemProperty -Path $gameBarPath -Name "UseNexusForGameBarEnabled" -Value 0 -Type DWord
        Set-ItemProperty -Path $gameBarPath -Name "AutoGameModeEnabled" -Value 0 -Type DWord
        
        # Disable Game Mode
        $gameModeUserPath = "HKCU:\SOFTWARE\Microsoft\GameBar"
        if (-not (Test-Path $gameModeUserPath)) {
            New-Item -Path $gameModeUserPath -Force | Out-Null
        }
        Set-ItemProperty -Path $gameModeUserPath -Name "AllowAutoGameMode" -Value 0 -Type DWord
        Set-ItemProperty -Path $gameModeUserPath -Name "AutoGameModeEnabled" -Value 0 -Type DWord
        
        # Disable Game DVR
        $gameDVRUserPath = "HKCU:\System\GameConfigStore"
        if (-not (Test-Path $gameDVRUserPath)) {
            New-Item -Path $gameDVRUserPath -Force | Out-Null
        }
        Set-ItemProperty -Path $gameDVRUserPath -Name "GameDVR_Enabled" -Value 0 -Type DWord
    } 
    catch {}
        
    # Configure Regional settings for Canadian English
    # Set system locale and geo location to Canada
    Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name "Locale" -Value "4105" -Type String
    Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name "LocaleName" -Value "en-CA" -Type String
    Set-ItemProperty -Path "HKCU:\Control Panel\International\Geo" -Name "Nation" -Value "39" -Type String  # 39 is the GeoID for Canada
    
    # Set Windows display language to English (Canada)
    $languagePath = "HKCU:\Control Panel\International\User Profile"
    if (-not (Test-Path $languagePath)) {
        New-Item -Path $languagePath -Force | Out-Null
    }
    Set-ItemProperty -Path $languagePath -Name "Languages" -Value "en-CA" -Type MultiString
    
    # Set date formats
    Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name "sShortDate" -Value "dd/MM/yyyy" -Type String
    Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name "sLongDate" -Value "dddd, MMMM dd, yyyy" -Type String
    
    # Set time formats (12-hour time with AM/PM)
    Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name "iTime" -Value "0" -Type String
    Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name "sTimeFormat" -Value "h:mm:ss tt" -Type String
    Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name "sShortTime" -Value "h:mm tt" -Type String
    Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name "s1159" -Value "AM" -Type String
    Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name "s2359" -Value "PM" -Type String
    
    # Configure File Explorer, Control Panel and Power settings
    # Open Explorer to "This PC" instead of Quick Access
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Value 1 -Type DWord
    
    # Set Control Panel view to Large Icons
    $controlPanelPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel"
    if (-not (Test-Path $controlPanelPath)) {
        New-Item -Path $controlPanelPath -Force | Out-Null
    }
    Set-ItemProperty -Path $controlPanelPath -Name "StartupPage" -Value 1 -Type DWord
    Set-ItemProperty -Path $controlPanelPath -Name "AllItemsIconView" -Value 0 -Type DWord
    
    # Configure taskbar settings
    # Create/ensure taskbar settings path exists
    $taskbarPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    if (-not (Test-Path $taskbarPath)) {
        New-Item -Path $taskbarPath -Force | Out-Null
    }
    
    # Taskbar alignment - Left (0) instead of Center (1)
    Set-ItemProperty -Path $taskbarPath -Name "TaskbarAl" -Value 0 -Type DWord
    
    # Search icon only (1) - options: Hidden (0), Icon (1), Search box (2)
    Set-ItemProperty -Path $taskbarPath -Name "SearchboxTaskbarMode" -Value 1 -Type DWord
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 1 -Type DWord -ErrorAction SilentlyContinue
    $searchPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband"
    if (-not (Test-Path $searchPath)) {
        New-Item -Path $searchPath -Force | Out-Null
    }
    Set-ItemProperty -Path $searchPath -Name "SearchboxTaskbarMode" -Value 1 -Type DWord -ErrorAction SilentlyContinue
    
    # Task View button - Off (0)
    Set-ItemProperty -Path $taskbarPath -Name "ShowTaskViewButton" -Value 0 -Type DWord
    
    # Widgets button - Off (0)
    Set-ItemProperty -Path $taskbarPath -Name "TaskbarDa" -Value 0 -Type DWord
    
    # Always show all taskbar icons and notifications
    # Method 1: Standard location
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "EnableAutoTray" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    
    # Method 2: Alternative location
    $sysTrayPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    if (Test-Path $sysTrayPath) {
        Set-ItemProperty -Path $sysTrayPath -Name "TaskbarSizeMove" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $sysTrayPath -Name "TaskbarSmallIcons" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $sysTrayPath -Name "TaskbarGlomLevel" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    }
    
    # Method 3: For newer Windows 11 builds
    $notificationPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband"
    if (-not (Test-Path $notificationPath)) {
        New-Item -Path $notificationPath -Force | Out-Null
    }
    Set-ItemProperty -Path $notificationPath -Name "EnableAutoTray" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    
    # Method 4: Direct systray settings
    $systraySettingsPath = "HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\TrayNotify"
    if (Test-Path $systraySettingsPath) {
        # Remove IconStreams and PastIconsStream to reset hidden status
        Remove-ItemProperty -Path $systraySettingsPath -Name "IconStreams" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $systraySettingsPath -Name "PastIconsStream" -ErrorAction SilentlyContinue
    }
    
    # Never hide labels (Windows 11)
    Set-ItemProperty -Path $taskbarPath -Name "TaskbarGlomLevel" -Value 1 -Type DWord

    # Try opening taskbar settings
    try {
        Start-Process "ms-settings:taskbar" -ErrorAction SilentlyContinue
    } catch {}

    # UAC SETTINGS
    # Check if running as administrator
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if ($isAdmin) {
        try {
            # Create the registry path if it doesn't exist
            $uacPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
            if (-not (Test-Path $uacPath)) {
                New-Item -Path $uacPath -Force | Out-Null
            }

            # Disable the secure desktop (dimming effect)
            Set-ItemProperty -Path $uacPath -Name "PromptOnSecureDesktop" -Value 0 -Type DWord
        }
        catch {}
    }

    # START MENU CONFIGURATION
    # Main Start Menu settings
    $startPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Start"
    if (-not (Test-Path $startPath)) {
        New-Item -Path $startPath -Force | Out-Null
    }
    
    # Hide recently added apps
    Set-ItemProperty -Path $startPath -Name "HideRecentlyAddedApps" -Value 1 -Type DWord
    
    # Hide most used apps
    Set-ItemProperty -Path $startPath -Name "ShowMostUsedApps" -Value 0 -Type DWord
    
    # Hide recently opened items
    if (-not (Test-Path "$startPath\RecentItems")) {
        New-Item -Path "$startPath\RecentItems" -Force | Out-Null
    }
    Set-ItemProperty -Path "$startPath\RecentItems" -Name "Enabled" -Value 0 -Type DWord
    
    # For Windows 11: Optimize for more pins
    # Disable recommendations/suggested content
    Set-ItemProperty -Path $startPath -Name "ShowRecommendedSection" -Value 0 -Type DWord
    
    # Try additional Windows 11 setting
    Set-ItemProperty -Path $startPath -Name "ShowRecommendedApps" -Value 0 -Type DWord
    
    # Advanced Start Menu settings (Windows 11)
    $advancedStartPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    if (-not (Test-Path $advancedStartPath)) {
        New-Item -Path $advancedStartPath -Force | Out-Null
    }
    
    # Disable "Show recently opened items" in Start, Jump Lists, and File Explorer
    Set-ItemProperty -Path $advancedStartPath -Name "Start_TrackDocs" -Value 0 -Type DWord
    
    # Disable web search results in Start Menu (Windows 11)
    if (-not (Test-Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer")) {
        New-Item -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "DisableSearchBoxSuggestions" -Value 1 -Type DWord
    
    # For Windows 11: Optimize Start layout for more pins
    $start11Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartPage"
    if (-not (Test-Path $start11Path)) {
        New-Item -Path $start11Path -Force | Out-Null
    }
    
    # Set minimal mode (no recommendations, more pin space)
    Set-ItemProperty -Path $start11Path -Name "MonitorOverride" -Value 1 -Type DWord
    
    # Make Start menu more compact to fit more pins
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarSi" -Value 0 -Type DWord
    
    # Cloud content settings - disable suggestions
    $cloudContentPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    if (-not (Test-Path $cloudContentPath)) {
        New-Item -Path $cloudContentPath -Force | Out-Null
    }
    
    # Disable all suggested apps and content
    Set-ItemProperty -Path $cloudContentPath -Name "SystemPaneSuggestionsEnabled" -Value 0 -Type DWord
    Set-ItemProperty -Path $cloudContentPath -Name "SubscribedContent-338388Enabled" -Value 0 -Type DWord
    Set-ItemProperty -Path $cloudContentPath -Name "SubscribedContent-314559Enabled" -Value 0 -Type DWord
    Set-ItemProperty -Path $cloudContentPath -Name "SubscribedContent-310093Enabled" -Value 0 -Type DWord
    Set-ItemProperty -Path $cloudContentPath -Name "SubscribedContent-338389Enabled" -Value 0 -Type DWord
    Set-ItemProperty -Path $cloudContentPath -Name "SubscribedContent-314563Enabled" -Value 0 -Type DWord
    Set-ItemProperty -Path $cloudContentPath -Name "SubscribedContent-353698Enabled" -Value 0 -Type DWord
}
catch {}

#----------------------------------------------------------------------------------
# SYSTEM-WIDE SETTINGS (requires elevation)
#----------------------------------------------------------------------------------

# Check if running as administrator for system settings
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
    # Change C drive label to "SYSTEM"
    try {
        $cDrive = Get-Volume -DriveLetter C
        if ($cDrive) {
            Set-Volume -DriveLetter C -NewFileSystemLabel "SYSTEM"
        }
    } catch {}

    # Set Power mode to High Performance
    try {
        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c  # High Performance power scheme GUID
    } catch {}

    # Set sleep settings to never for both AC and DC
    try {
        # Sleep timeout - Never (0)
        powercfg /change standby-timeout-ac 0
        powercfg /change standby-timeout-dc 0
    } catch {}

    # Set screen timeout to never for both AC and DC
    try {
        # Display timeout - Never (0)
        powercfg /change monitor-timeout-ac 0
        powercfg /change monitor-timeout-dc 0
    } catch {}
}

# Restart Explorer to apply settings
try {
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    # Explorer will restart automatically
} catch {}