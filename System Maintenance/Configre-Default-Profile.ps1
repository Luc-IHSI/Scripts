<#
    Configre-Default-Profile.ps1

    Purpose:
      1) Write “HKCU”-style customizations into HKEY_USERS\.DEFAULT so all new users inherit them.
      2) Log each step (success or error) to C:\Windows\Temp\ConfigureUserSettings.log
      3) Emit Write-Host for every success/error (so NinjaOne’s Activity pane shows them).

    Context: Run as SYSTEM on a fresh Windows 11 24H2 endpoint.
    Author: Revised (June 2025) to handle “Attempted to perform an unauthorized operation” on Taskbar settings.
#>

#------------------------------------------------------------------------------
# LOGGING HELPER
#------------------------------------------------------------------------------
$logFile = "C:\Windows\Temp\ConfigureUserSettings.log"
Function Log {
    Param([string]$Message)
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    "$ts  $Message" | Out-File $logFile -Append -Encoding utf8
}

#------------------------------------------------------------------------------
# GLOBAL COUNTERS
#------------------------------------------------------------------------------
$successCount = 0
$errorCount   = 0

Function Mark-Success {
    Param([string]$Step)
    $global:successCount++
    $msg = "SUCCESS: $Step"
    Log $msg
    Write-Host $msg
}

Function Mark-Error {
    Param(
        [string]$Step,
        [string]$ErrorMessage
    )
    $global:errorCount++
    $msg = "ERROR: $Step - $ErrorMessage"
    Log $msg
    Write-Host $msg
}

#------------------------------------------------------------------------------
# HELPER: Ensure a registry key exists under HKEY_USERS\.DEFAULT
#------------------------------------------------------------------------------
Function Ensure-DefKey {
    Param([string]$PathUnderDefault)
    # e.g. input: "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $fullPath = "Registry::HKEY_USERS\.DEFAULT\$PathUnderDefault"
    if (-not (Test-Path $fullPath)) {
        Try {
            New-Item -Path $fullPath -Force | Out-Null
            Mark-Success "Created registry key: HKEY_USERS\.DEFAULT\$PathUnderDefault"
        }
        Catch {
            Mark-Error "Creating registry key HKEY_USERS\.DEFAULT\$PathUnderDefault" $_
        }
    }
}

#------------------------------------------------------------------------------
# BEGIN MAIN
#------------------------------------------------------------------------------
Log '=== Starting DefaultProfile configuration ==='

#------------------------------------------------------------------------------
# 1) DESKTOP / FILE EXPLORER SETTINGS
#------------------------------------------------------------------------------
Try {
    Ensure-DefKey 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'

    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' `
      -Name 'HideFileExt' `
      -Value 0 `
      -ErrorAction Stop
    Mark-Success 'Set HideFileExt = 0 under Explorer\Advanced'

    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' `
      -Name 'Hidden' `
      -Value 1 `
      -ErrorAction Stop
    Mark-Success 'Set Hidden = 1 under Explorer\Advanced'
}
Catch {
    Mark-Error 'Applying Desktop/Explorer settings' $_
}

#------------------------------------------------------------------------------
# 2) START MENU TWEAKS
#------------------------------------------------------------------------------
Try {
    Ensure-DefKey 'SOFTWARE\Microsoft\Windows\CurrentVersion\Start'

    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Start' `
      -Name 'HideRecentlyAddedApps' `
      -Value 1 `
      -ErrorAction Stop
    Mark-Success 'Set Start\HideRecentlyAddedApps = 1'
}
Catch {
    Mark-Error 'Applying Start Menu tweaks' $_
}

#------------------------------------------------------------------------------
# 3) NETWORK CONFIGURATION DEFAULTS
#------------------------------------------------------------------------------
Try {
    Ensure-DefKey 'SOFTWARE\Microsoft\Windows NT\CurrentVersion\Network\NwCategoryWizard'
    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Network\NwCategoryWizard' `
      -Name 'DefaultCategory' `
      -Value 1 `
      -ErrorAction Stop
    Mark-Success 'Set Network DefaultCategory = 1 (Private)'

    Ensure-DefKey 'SOFTWARE\Microsoft\Windows\CurrentVersion\NcdAutoSetup\Private'
    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\NcdAutoSetup\Private' `
      -Name 'AutoSetup' `
      -Value 0 `
      -ErrorAction Stop
    Mark-Success 'Set NcdAutoSetup\Private\AutoSetup = 0'

    Ensure-DefKey 'SOFTWARE\Microsoft\Windows\CurrentVersion\NcdAutoSetup\Public'
    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\NcdAutoSetup\Public' `
      -Name 'AutoSetup' `
      -Value 0 `
      -ErrorAction Stop
    Mark-Success 'Set NcdAutoSetup\Public\AutoSetup = 0'
}
Catch {
    Mark-Error 'Applying Network defaults' $_
}

#------------------------------------------------------------------------------
# 4) DISABLE GAME BAR / GAME MODE
#------------------------------------------------------------------------------
Try {
    Ensure-DefKey 'SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR'
    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR' `
      -Name 'AppCaptureEnabled' `
      -Value 0 `
      -ErrorAction Stop
    Mark-Success 'Disabled GameDVR\AppCaptureEnabled'

    Ensure-DefKey 'SOFTWARE\Microsoft\GameBar'
    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\SOFTWARE\Microsoft\GameBar' `
      -Name 'UseNexusForGameBarEnabled' `
      -Value 0 `
      -ErrorAction Stop
    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\SOFTWARE\Microsoft\GameBar' `
      -Name 'AutoGameModeEnabled' `
      -Value 0 `
      -ErrorAction Stop
    Mark-Success 'Disabled GameBar (UseNexusForGameBarEnabled, AutoGameModeEnabled)'

    Ensure-DefKey 'System\GameConfigStore'
    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\System\GameConfigStore' `
      -Name 'GameDVR_Enabled' `
      -Value 0 `
      -ErrorAction Stop
    Mark-Success 'Disabled System\GameConfigStore\GameDVR_Enabled'
}
Catch {
    Mark-Error 'Disabling Game Bar/Game Mode' $_
}

#------------------------------------------------------------------------------
# 5) REGIONAL / LANGUAGE SETTINGS (Canadian English)
#------------------------------------------------------------------------------
Try {
    Ensure-DefKey 'Control Panel\International'
    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\Control Panel\International' `
      -Name 'Locale' `
      -Value '4105' `
      -ErrorAction Stop
    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\Control Panel\International' `
      -Name 'LocaleName' `
      -Value 'en-CA' `
      -ErrorAction Stop
    Mark-Success 'Set International\Locale = en-CA (4105)'

    Ensure-DefKey 'Control Panel\International\Geo'
    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\Control Panel\International\Geo' `
      -Name 'Nation' `
      -Value '39' `
      -ErrorAction Stop
    Mark-Success 'Set International\Geo\Nation = 39 (Canada)'

    Ensure-DefKey 'Control Panel\International\User Profile'
    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\Control Panel\International\User Profile' `
      -Name 'Languages' `
      -Value @('en-CA') `
      -ErrorAction Stop
    Mark-Success 'Set International\User Profile\Languages = en-CA'

    # Date formats
    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\Control Panel\International' `
      -Name 'sShortDate' `
      -Value 'dd/MM/yyyy' `
      -ErrorAction Stop
    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\Control Panel\International' `
      -Name 'sLongDate' `
      -Value 'dddd, MMMM dd, yyyy' `
      -ErrorAction Stop
    Mark-Success 'Set date formats'

    # Time formats (12-hour)
    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\Control Panel\International' `
      -Name 'iTime' `
      -Value '0' `
      -ErrorAction Stop
    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\Control Panel\International' `
      -Name 'sTimeFormat' `
      -Value 'h:mm:ss tt' `
      -ErrorAction Stop
    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\Control Panel\International' `
      -Name 'sShortTime' `
      -Value 'h:mm tt' `
      -ErrorAction Stop
    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\Control Panel\International' `
      -Name 's1159' `
      -Value 'AM' `
      -ErrorAction Stop
    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\Control Panel\International' `
      -Name 's2359' `
      -Value 'PM' `
      -ErrorAction Stop
    Mark-Success 'Set time formats (12-hour)'
}
Catch {
    Mark-Error 'Applying Regional/Language settings' $_
}

#------------------------------------------------------------------------------
# 6) EXPLORER / CONTROL PANEL DEFAULTS
#------------------------------------------------------------------------------
Try {
    Ensure-DefKey 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' `
      -Name 'LaunchTo' `
      -Value 1 `
      -ErrorAction Stop
    Mark-Success 'Set Explorer\LaunchTo = 1 (This PC)'

    Ensure-DefKey 'Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel'
    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel' `
      -Name 'StartupPage' `
      -Value 1 `
      -ErrorAction Stop
    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel' `
      -Name 'AllItemsIconView' `
      -Value 0 `
      -ErrorAction Stop
    Mark-Success 'Set ControlPanel view = Large Icons'
}
Catch {
    Mark-Error 'Applying Explorer/Control Panel defaults' $_
}

#------------------------------------------------------------------------------
# 7) TASKBAR SETTINGS (Windows 11) with per-value Try/Catch
#------------------------------------------------------------------------------
# Each Set-ItemProperty is wrapped in its own Try/Catch so that
# one “unauthorized” won’t stop the rest.
Ensure-DefKey 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'

# TaskbarAl = 0
Try {
    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' `
      -Name 'TaskbarAl' `
      -Value 0 `
      -ErrorAction Stop
    Mark-Success 'Set TaskbarAl = 0 (Left)'
}
Catch {
    Mark-Error 'Setting TaskbarAl' $_
}

# SearchboxTaskbarMode = 1 under Explorer\Advanced
Try {
    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' `
      -Name 'SearchboxTaskbarMode' `
      -Value 1 `
      -ErrorAction Stop
    Mark-Success 'Set SearchboxTaskbarMode = 1 under Explorer\Advanced'
}
Catch {
    Mark-Error 'Setting SearchboxTaskbarMode under Explorer\Advanced' $_
}

# SearchboxTaskbarMode = 1 under Search
Ensure-DefKey 'SOFTWARE\Microsoft\Windows\CurrentVersion\Search'
Try {
    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' `
      -Name 'SearchboxTaskbarMode' `
      -Value 1 `
      -ErrorAction Stop
    Mark-Success 'Set SearchboxTaskbarMode = 1 under Search'
}
Catch {
    Mark-Error 'Setting SearchboxTaskbarMode under Search' $_
}

# SearchboxTaskbarMode = 1 under Taskband
Ensure-DefKey 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband'
Try {
    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband' `
      -Name 'SearchboxTaskbarMode' `
      -Value 1 `
      -ErrorAction Stop
    Mark-Success 'Set SearchboxTaskbarMode = 1 under Taskband'
}
Catch {
    Mark-Error 'Setting SearchboxTaskbarMode under Taskband' $_
}

# ShowTaskViewButton = 0
Try {
    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' `
      -Name 'ShowTaskViewButton' `
      -Value 0 `
      -ErrorAction Stop
    Mark-Success 'Set ShowTaskViewButton = 0'
}
Catch {
    Mark-Error 'Setting ShowTaskViewButton' $_
}

# TaskbarDa = 0 (Widgets off)
Try {
    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' `
      -Name 'TaskbarDa' `
      -Value 0 `
      -ErrorAction Stop
    Mark-Success 'Set TaskbarDa = 0 (Widgets off)'
}
Catch {
    Mark-Error 'Setting TaskbarDa' $_
}

# EnableAutoTray = 0
Ensure-DefKey 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer'
Try {
    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' `
      -Name 'EnableAutoTray' `
      -Value 0 `
      -ErrorAction Stop
    Mark-Success 'Set EnableAutoTray = 0 (always show all icons)'
}
Catch {
    Mark-Error 'Setting EnableAutoTray' $_
}

# TaskbarSizeMove = 0 (silently continue if missing)
Try {
    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' `
      -Name 'TaskbarSizeMove' `
      -Value 0 `
      -ErrorAction Stop
    Mark-Success 'Set TaskbarSizeMove = 0'
}
Catch {
    Mark-Error 'Setting TaskbarSizeMove' $_
}

# TaskbarSmallIcons = 0 (silently continue if missing)
Try {
    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' `
      -Name 'TaskbarSmallIcons' `
      -Value 0 `
      -ErrorAction Stop
    Mark-Success 'Set TaskbarSmallIcons = 0'
}
Catch {
    Mark-Error 'Setting TaskbarSmallIcons' $_
}

# TaskbarGlomLevel = 0 (silently continue if missing)
Try {
    Set-ItemProperty `
      -Path 'Registry::HKEY_USERS\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' `
      -Name 'TaskbarGlomLevel' `
      -Value 0 `
      -ErrorAction Stop
    Mark-Success 'Set TaskbarGlomLevel = 0'
}
Catch {
    Mark-Error 'Set
