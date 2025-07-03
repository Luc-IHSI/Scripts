# Ensure the script runs as administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Restarting script with administrator privileges..."
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Stop and disable services related to GoTo, LogMeIn, Citrix, G2A, and GoTo Corporate before killing processes
$servicesToRemove = Get-Service | Where-Object { $_.DisplayName -match "GoTo|LogMeIn|Citrix|Receiver|Workspace|G2A|GoTo Corporate" }
foreach ($service in $servicesToRemove) {
    try {
        Write-Host "Attempting to stop and disable service: $($service.Name)"
        Stop-Service -Name $service.Name -Force -ErrorAction SilentlyContinue
        Set-Service -Name $service.Name -StartupType Disabled -ErrorAction SilentlyContinue
        sc.exe delete $service.Name | Out-Null
        Write-Host "Successfully stopped and disabled service: $($service.Name)"
    } catch {
        Write-Host "Failed to stop or disable service: $($service.Name). Please check manually."
    }
}

# Kill all GoToAssist, GoToMeeting, LogMeIn, Citrix, G2A, and GoTo Corporate processes with logging
$processesToKill = @("goto*", "logmein", "logmeinrescue", "lmiguardian", "citrix", "ctxsession", "wfica32", "receiver", "g2a*", "goto corporate*")
foreach ($processPattern in $processesToKill) {
    try {
        $runningProcesses = Get-Process -Name $processPattern -ErrorAction SilentlyContinue
        if ($runningProcesses) {
            $runningProcesses | ForEach-Object {
                Write-Host "Attempting to terminate process: $($_.Name) (PID: $($_.Id))"
                Stop-Process -Id $_.Id -Force -ErrorAction Stop
                Write-Host "Successfully terminated process: $($_.Name) (PID: $($_.Id))"
            }
        } else {
            Write-Host "No processes found matching pattern: $processPattern"
        }
    } catch {
        Write-Host "Failed to terminate processes matching pattern: $processPattern. Please check manually."
    }
}

# Uninstall GoTo, LogMeIn, Citrix, G2A, and GoTo Corporate software silently
$gotoUninstallPaths = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", `
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" `
    -ErrorAction SilentlyContinue | Where-Object {
        $_.GetValue("DisplayName") -match "GoToAssist|GoToMeeting|LogMeIn|Citrix|Receiver|Workspace|G2A|GoTo Corporate"
    }

foreach ($uninstallKey in $gotoUninstallPaths) {
    $uninstallString = $uninstallKey.GetValue("UninstallString")
    if ($uninstallString) {
        try {
            Write-Host "Attempting to uninstall: $($uninstallKey.GetValue("DisplayName"))"
            Start-Process -FilePath $uninstallString -ArgumentList "/S" -Wait -ErrorAction Stop
            Write-Host "Successfully uninstalled: $($uninstallKey.GetValue("DisplayName"))"
        } catch {
            Write-Host "Failed to run uninstaller for $($uninstallKey.GetValue("DisplayName")). Please follow up manually."
        }
    } else {
        Write-Host "Uninstaller not found for $($uninstallKey.GetValue("DisplayName")). Proceeding with manual removal..."
    }
}

# Enhanced folder deletion with ownership and permission reset
function Remove-DeleteFolder {
    param (
        [string]$FolderPath
    )
    if (Test-Path $FolderPath) {
        try {
            Write-Host "Attempting to take ownership of folder: $FolderPath"
            takeown /F $FolderPath /R /D Y | Out-Null
            icacls $FolderPath /grant Administrators:F /T | Out-Null
            Write-Host "Ownership and permissions updated for folder: $FolderPath"
            Remove-Item -Path $FolderPath -Recurse -Force -ErrorAction Stop
            Write-Host "Successfully deleted folder: $FolderPath"
        } catch {
            Write-Host "Failed to delete folder: $FolderPath. Please check manually."
        }
    } else {
        Write-Host "Folder not found: $FolderPath"
    }
}

# Updated folder deletion logic to include GoTo Corporate
$foldersToDelete = @(
    "C:\Program Files (x86)\GoTo*",     # GoTo software installation folders
    "C:\Program Files (x86)\LogMeIn*", # LogMeIn software installation folders
    "C:\Program Files (x86)\Citrix*",  # Citrix software installation folders
    "C:\Program Files (x86)\G2A*",     # G2A software installation folders
    "C:\Program Files (x86)\GoTo Corporate*", # GoTo Corporate software installation folders
    "C:\ProgramData\GoTo*",            # GoTo shared data folders
    "C:\ProgramData\LogMeIn*",         # LogMeIn shared data folders
    "C:\ProgramData\Citrix*",          # Citrix shared data folders
    "C:\ProgramData\G2A*",             # G2A shared data folders
    "C:\ProgramData\GoTo Corporate*",  # GoTo Corporate shared data folders
    "$env:APPDATA\GoTo*",              # GoTo user-specific AppData folders
    "$env:APPDATA\LogMeIn*",           # LogMeIn user-specific AppData folders
    "$env:APPDATA\Citrix*",            # Citrix user-specific AppData folders
    "$env:APPDATA\G2A*",               # G2A user-specific AppData folders
    "$env:APPDATA\GoTo Corporate*",    # GoTo Corporate user-specific AppData folders
    "$env:LOCALAPPDATA\GoTo*",         # GoTo user-specific LocalAppData folders
    "$env:LOCALAPPDATA\LogMeIn*",      # LogMeIn user-specific LocalAppData folders
    "$env:LOCALAPPDATA\Citrix*",       # Citrix user-specific LocalAppData folders
    "$env:LOCALAPPDATA\G2A*",          # G2A user-specific LocalAppData folders
    "$env:LOCALAPPDATA\GoTo Corporate*" # GoTo Corporate user-specific LocalAppData folders
)
foreach ($folder in $foldersToDelete) {
    Remove-DeleteFolder -FolderPath $folder
}

# Fix desktop shortcut removal logic to include GoTo Corporate
$desktopPaths = @(
    "$env:PUBLIC\Desktop",   # Public desktop
    "$env:USERPROFILE\Desktop" # Current user's desktop
)
foreach ($desktopPath in $desktopPaths) {
    if (Test-Path $desktopPath) {
        Get-ChildItem -Path $desktopPath -Filter "*.lnk" -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -match "^(GoTo|LogMeIn|Citrix|Receiver|Workspace|G2A|GoTo Corporate)"
        } | ForEach-Object {
            try {
                Write-Host "Attempting to delete desktop icon: $($_.FullName)"
                Remove-Item -Path $_.FullName -Force -ErrorAction Stop
                Write-Host "Successfully deleted desktop icon: $($_.FullName)"
            } catch {
                Write-Host "Failed to delete desktop icon: $($_.FullName). Please check manually."
            }
        }
    } else {
        Write-Host "Desktop path not found: $desktopPath"
    }
}

# Forcefully remove leftover registry entries (including GoTo Corporate)
$registryPathsToDelete = @(
    "HKLM:\SOFTWARE\GoTo*",                  # GoTo registry for 64-bit systems
    "HKLM:\SOFTWARE\WOW6432Node\GoTo*",      # GoTo registry for 32-bit systems
    "HKLM:\SOFTWARE\LogMeIn*",               # LogMeIn registry for 64-bit systems
    "HKLM:\SOFTWARE\WOW6432Node\LogMeIn*",   # LogMeIn registry for 32-bit systems
    "HKLM:\SOFTWARE\Citrix*",                # Citrix registry for 64-bit systems
    "HKLM:\SOFTWARE\WOW6432Node\Citrix*",    # Citrix registry for 32-bit systems
    "HKLM:\SOFTWARE\G2A*",                   # G2A registry for 64-bit systems
    "HKLM:\SOFTWARE\WOW6432Node\G2A*",       # G2A registry for 32-bit systems
    "HKLM:\SOFTWARE\GoTo Corporate*",        # GoTo Corporate registry for 64-bit systems
    "HKLM:\SOFTWARE\WOW6432Node\GoTo Corporate*", # GoTo Corporate registry for 32-bit systems
    "HKCU:\SOFTWARE\GoTo*",                  # GoTo user-specific registry
    "HKCU:\SOFTWARE\LogMeIn*",               # LogMeIn user-specific registry
    "HKCU:\SOFTWARE\Citrix*",                # Citrix user-specific registry
    "HKCU:\SOFTWARE\G2A*",                   # G2A user-specific registry
    "HKCU:\SOFTWARE\GoTo Corporate*"         # GoTo Corporate user-specific registry
)
foreach ($regPath in $registryPathsToDelete) {
    if (Test-Path $regPath) {
        try {
            Write-Host "Attempting to delete registry path: $regPath"
            Remove-Item -Path $regPath -Recurse -Force -ErrorAction Stop
            Write-Host "Successfully deleted registry path: $regPath"
        } catch {
            Write-Host "Failed to delete registry path: $regPath. Please check manually."
        }
    } else {
        Write-Host "Registry path not found: $regPath"
    }
}

# Check and remove scheduled tasks related to GoTo, LogMeIn, Citrix, and G2A software
try {
    $scheduledTasks = schtasks /Query /FO LIST /V | Select-String -Pattern "GoTo|LogMeIn|Citrix|Receiver|Workspace|G2A"
    if ($scheduledTasks) {
        foreach ($task in $scheduledTasks) {
            $taskName = ($task -split ":")[1].Trim()
            Write-Host "Attempting to delete scheduled task: $taskName"
            schtasks /Delete /TN $taskName /F | Out-Null
            Write-Host "Successfully deleted scheduled task: $taskName"
        }
    } else {
        Write-Host "No scheduled tasks related to GoTo, LogMeIn, Citrix, or G2A software found."
    }
} catch {
    Write-Host "Failed to query or delete scheduled tasks. Please check manually."
}

# Aggressively remove leftover services related to GoTo, LogMeIn, and Citrix software
$servicesToRemove = Get-Service | Where-Object { $_.DisplayName -match "GoTo|LogMeIn|Citrix|Receiver|Workspace" }
foreach ($service in $servicesToRemove) {
    try {
        Write-Host "Attempting to stop and delete service: $($service.Name)"
        Stop-Service -Name $service.Name -Force -ErrorAction SilentlyContinue
        sc.exe delete $service.Name | Out-Null
        Write-Host "Successfully deleted service: $($service.Name)"
    } catch {
        Write-Host "Failed to delete service: $($service.Name). Please check manually."
    }
}

# Check for hidden files and folders
$hiddenFoldersToDelete = @(
    "C:\ProgramData\GoTo*",             # GoTo shared data folders
    "$env:APPDATA\GoTo*",               # GoTo user-specific AppData folders
    "$env:LOCALAPPDATA\GoTo*"           # GoTo user-specific LocalAppData folders
)
foreach ($folder in $hiddenFoldersToDelete) {
    if (Test-Path $folder) {
        try {
            Write-Host "Attempting to delete hidden folder: $folder"
            Remove-Item -Path $folder -Recurse -Force -ErrorAction Stop
            Write-Host "Successfully deleted hidden folder: $folder"
        } catch {
            Write-Host "Failed to delete hidden folder: $folder. Please check manually."
        }
    } else {
        Write-Host "Hidden folder not found: $folder"
    }
}

# Specifically remove registry entries for "GoToAssist Unattended", "Customer", and "Remote Support Unattended"
$targetSoftware = @(
    "GoToAssist Unattended",
    "GoToAssist Customer",
    "GoToAssist Remote Support Unattended"
)
$uninstallRegistryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)
foreach ($path in $uninstallRegistryPaths) {
    foreach ($software in $targetSoftware) {
        $key = Get-ChildItem -Path $path -ErrorAction SilentlyContinue | Where-Object {
            $_.GetValue("DisplayName") -like "*$software*"
        }
        if ($key) {
            try {
                Write-Host "Attempting to delete registry key for $software"
                Remove-Item -Path $key.PSPath -Recurse -Force -ErrorAction Stop
                Write-Host "Successfully deleted registry key for $software"
            } catch {
                Write-Host "Failed to delete registry key for $software. Please check manually."
            }
        } else {
            Write-Host "Registry key for $software not found."
        }
    }
}

# Recheck and forcefully remove services related to "GoToAssist Unattended", "Customer", and "Remote Support Unattended"
$servicesToRemove = Get-Service | Where-Object { $_.DisplayName -match "GoToAssist Unattended|GoToAssist Customer|GoToAssist Remote Support Unattended" }
foreach ($service in $servicesToRemove) {
    try {
        Write-Host "Attempting to stop and delete service: $($service.Name)"
        Stop-Service -Name $service.Name -Force -ErrorAction SilentlyContinue
        sc.exe delete $service.Name | Out-Null
        Write-Host "Successfully deleted service: $($service.Name)"
    } catch {
        Write-Host "Failed to delete service: $($service.Name). Please check manually."
    }
}

# Recheck for hidden files and folders related to "GoToAssist Unattended", "Customer", and "Remote Support Unattended"
$foldersToDelete = @(
    "C:\Program Files (x86)\GoToAssist Unattended*",
    "C:\Program Files (x86)\GoToAssist Customer*",
    "C:\Program Files (x86)\GoToAssist Remote Support Unattended*",
    "C:\ProgramData\GoToAssist Unattended*",
    "C:\ProgramData\GoToAssist Customer*",
    "C:\ProgramData\GoToAssist Remote Support Unattended*",
    "$env:APPDATA\GoToAssist Unattended*",
    "$env:APPDATA\GoToAssist Customer*",
    "$env:APPDATA\GoToAssist Remote Support Unattended*",
    "$env:LOCALAPPDATA\GoToAssist Unattended*",
    "$env:LOCALAPPDATA\GoToAssist Customer*",
    "$env:LOCALAPPDATA\GoToAssist Remote Support Unattended*"
)
foreach ($folder in $foldersToDelete) {
    Remove-DeleteFolder -FolderPath $folder
}

# Recheck and remove scheduled tasks related to "GoToAssist Unattended", "Customer", and "Remote Support Unattended"
try {
    $scheduledTasks = schtasks /Query /FO LIST /V | Select-String -Pattern "GoToAssist Unattended|GoToAssist Customer|GoToAssist Remote Support Unattended"
    if ($scheduledTasks) {
        foreach ($task in $scheduledTasks) {
            $taskName = ($task -split ":")[1].Trim()
            Write-Host "Attempting to delete scheduled task: $taskName"
            schtasks /Delete /TN $taskName /F | Out-Null
            Write-Host "Successfully deleted scheduled task: $taskName"
        }
    } else {
        Write-Host "No scheduled tasks related to GoToAssist Unattended, Customer, or Remote Support Unattended found."
    }
} catch {
    Write-Host "Failed to query or delete scheduled tasks. Please check manually."
}

# Recheck for hidden files and folders in additional locations
$additionalFoldersToDelete = @(
    "C:\Users\*\AppData\Local\GoTo*",             # GoTo user-specific Local AppData folders
    "C:\Users\*\AppData\Local\LogMeIn*",          # LogMeIn user-specific Local AppData folders
    "C:\Users\*\AppData\Local\Citrix*",           # Citrix user-specific Local AppData folders
    "C:\Users\*\AppData\Local\G2A*",              # G2A user-specific Local AppData folders
    "C:\Users\Public\GoTo*",                      # GoTo public folders
    "C:\Users\Public\LogMeIn*",                   # LogMeIn public folders
    "C:\Users\Public\Citrix*",                    # Citrix public folders
    "C:\Users\Public\G2A*",                       # G2A public folders
    "C:\Windows\System32\GoTo*",                  # GoTo-related files in System32
    "C:\Windows\System32\LogMeIn*",               # LogMeIn-related files in System32
    "C:\Windows\System32\Citrix*",                # Citrix-related files in System32
    "C:\Windows\System32\G2A*",                   # G2A-related files in System32
    "C:\ProgramData\GoTo*",                       # GoTo shared data folders
    "C:\ProgramData\LogMeIn*",                    # LogMeIn shared data folders
    "C:\ProgramData\Citrix*",                     # Citrix shared data folders
    "C:\ProgramData\G2A*"                         # G2A shared data folders
)
foreach ($folder in $additionalFoldersToDelete) {
    Remove-DeleteFolder -FolderPath $folder
}

# Recheck for files and folders in all public folders, Public\Downloads, and System32
$additionalFoldersAndFilesToDelete = @(
    "C:\Users\Public\GoTo*",                      # GoTo public folders
    "C:\Users\Public\LogMeIn*",                   # LogMeIn public folders
    "C:\Users\Public\Citrix*",                    # Citrix public folders
    "C:\Users\Public\G2A*",                       # G2A public folders
    "C:\Users\Public\Downloads\GoTo*",            # GoTo files in Public\Downloads
    "C:\Users\Public\Downloads\LogMeIn*",         # LogMeIn files in Public\Downloads
    "C:\Users\Public\Downloads\Citrix*",          # Citrix files in Public\Downloads
    "C:\Users\Public\Downloads\G2A*",             # G2A files in Public\Downloads
    "C:\Windows\System32\GoTo*",                  # GoTo-related files in System32
    "C:\Windows\System32\LogMeIn*",               # LogMeIn-related files in System32
    "C:\Windows\System32\Citrix*",                # Citrix-related files in System32
    "C:\Windows\System32\G2A*"                    # G2A-related files in System32
)
foreach ($path in $additionalFoldersAndFilesToDelete) {
    if (Test-Path $path) {
        try {
            Write-Host "Attempting to delete: $path"
            Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
            Write-Host "Successfully deleted: $path"
        } catch {
            Write-Host "Failed to delete: $path. Please check manually."
        }
    } else {
        Write-Host "Path not found: $path"
    }
}

# Recheck for hidden files and folders related to "GoToAssist Unattended", "Customer", and "Remote Support Unattended"
$foldersToDelete = @(
    "C:\Program Files (x86)\GoToAssist Unattended*",
    "C:\Program Files (x86)\GoToAssist Customer*",
    "C:\Program Files (x86)\GoToAssist Remote Support Unattended*",
    "C:\ProgramData\GoToAssist Unattended*",
    "C:\ProgramData\GoToAssist Customer*",
    "C:\ProgramData\GoToAssist Remote Support Unattended*",
    "C:\Users\*\AppData\Local\GoToAssist Unattended*",
    "C:\Users\*\AppData\Local\GoToAssist Customer*",
    "C:\Users\*\AppData\Local\GoToAssist Remote Support Unattended*",
    "C:\Windows\System32\GoToAssist Unattended*",
    "C:\Windows\System32\GoToAssist Customer*",
    "C:\Windows\System32\GoToAssist Remote Support Unattended*"
)
foreach ($folder in $foldersToDelete) {
    Remove-DeleteFolder -FolderPath $folder
}

# Recheck for files and folders in AppData (Local and Roaming) for all users
$additionalAppDataToDelete = @(
    "C:\Users\*\AppData\Local\GoTo*",             # GoTo user-specific Local AppData folders
    "C:\Users\*\AppData\Local\LogMeIn*",          # LogMeIn user-specific Local AppData folders
    "C:\Users\*\AppData\Local\Citrix*",           # Citrix user-specific Local AppData folders
    "C:\Users\*\AppData\Local\G2A*",              # G2A user-specific Local AppData folders
    "C:\Users\*\AppData\Roaming\GoTo*",           # GoTo user-specific Roaming AppData folders
    "C:\Users\*\AppData\Roaming\LogMeIn*",        # LogMeIn user-specific Roaming AppData folders
    "C:\Users\*\AppData\Roaming\Citrix*",         # Citrix user-specific Roaming AppData folders
    "C:\Users\*\AppData\Roaming\G2A*",            # G2A user-specific Roaming AppData folders
    "C:\Windows\SysWOW64\config\systemprofile\AppData\Local\GoTo*",  # GoTo in SysWOW64 AppData
    "C:\Windows\SysWOW64\config\systemprofile\AppData\Local\LogMeIn*", # LogMeIn in SysWOW64 AppData
    "C:\Windows\SysWOW64\config\systemprofile\AppData\Local\Citrix*",  # Citrix in SysWOW64 AppData
    "C:\Windows\SysWOW64\config\systemprofile\AppData\Local\G2A*"      # G2A in SysWOW64 AppData
)
foreach ($path in $additionalAppDataToDelete) {
    if (Test-Path $path) {
        try {
            Write-Host "Attempting to delete: $path"
            Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
            Write-Host "Successfully deleted: $path"
        } catch {
            Write-Host "Failed to delete: $path. Please check manually."
        }
    } else {
        Write-Host "Path not found: $path"
    }
}

# # Function to search and delete registry keys system-wide
# function Search-And-DeleteRegistryKeys {
#     param (
#         [string[]]$Keywords
#     )
#     foreach ($keyword in $Keywords) {
#         Write-Host "Searching registry for keyword: $keyword"
#         $registryPaths = @(
#             "HKLM:\SOFTWARE",
#             "HKLM:\SOFTWARE\WOW6432Node",
#             "HKCU:\SOFTWARE"
#         )
#         foreach ($path in $registryPaths) {
#             try {
#                 $keys = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue | Where-Object {
#                     $_.Name -match $keyword
#                 }
#                 foreach ($key in $keys) {
#                     Write-Host "Attempting to delete registry key: $($key.PSPath)"
#                     Remove-Item -Path $key.PSPath -Recurse -Force -ErrorAction Stop
#                     Write-Host "Successfully deleted registry key: $($key.PSPath)"
#                 }
#             } catch {
#                 Write-Host "Failed to search or delete registry keys for keyword: $keyword. Please check manually."
#             }
#         }
#     }
# }

# # Function to search and delete files and folders system-wide
# function Search-And-DeleteFilesAndFolders {
#     param (
#         [string[]]$Keywords
#     )
#     foreach ($keyword in $Keywords) {
#         Write-Host "Searching files and folders for keyword: $keyword"
#         $pathsToSearch = @(
#             "C:\Program Files",
#             "C:\Program Files (x86)",
#             "C:\ProgramData",
#             "C:\Users",
#             "C:\Windows\System32"
#         )
#         foreach ($path in $pathsToSearch) {
#             try {
#                 $items = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue | Where-Object {
#                     $_.Name -match $keyword
#                 }
#                 foreach ($item in $items) {
#                     if (Test-Path $item.FullName) {
#                         Write-Host "Attempting to delete: $($item.FullName)"
#                         Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
#                         Write-Host "Successfully deleted: $($item.FullName)"
#                     }
#                 }
#             } catch {
#                 Write-Host "Failed to search or delete files and folders for keyword: $keyword. Please check manually."
#             }
#         }
#     }
# }

# # System-wide search and delete for specified keywords
# $keywordsToSearch = @("GoToAssist", "LogMeIn", "Citrix", "G2A", "Receiver", "Workspace")
# Search-And-DeleteRegistryKeys -Keywords $keywordsToSearch
# Search-And-DeleteFilesAndFolders -Keywords $keywordsToSearch

# Notify the user of completion
Write-Host "GoTo, LogMeIn, and Citrix software have been completely removed from the system."
