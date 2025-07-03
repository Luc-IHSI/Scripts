#Requires -Version 5.1

<#
.SYNOPSIS
    Hides or shows the 'News and Interests' tab in the taskbar. On Windows 11, it hides or shows the widgets tab.
.DESCRIPTION
    Hides or shows the 'News and Interests' tab in the taskbar. On Windows 11, it hides or shows the widgets tab.
.EXAMPLE
    (No Parameters)
    
    WARNING: Hiding News and Interests from the taskbar for all users!
    Registry::HKEY_USERS\S-1-12-1-2117605486-1182246982-3318994623-3070967164\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDa changed from 1 to 0
    Registry::HKEY_USERS\S-1-5-21-4122835015-3639794443-155648563-1001\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDa changed from 1 to 0
    WARNING: This script will take effect the next time the user completes a full sign-in or restarts.

PARAMETER: -Enable
    Reveals the 'News and Interests' tab in the taskbar.
.EXAMPLE
    -Enable

    Revealing News and Interests for all users!
    Registry::HKEY_USERS\S-1-12-1-2117605486-1182246982-3318994623-3070967164\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDa changed from 0 to 1
    Registry::HKEY_USERS\S-1-5-21-4122835015-3639794443-155648563-1001\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDa changed from 0 to 1
    WARNING: This script will take effect the next time the user completes a full sign-in or restarts.

PARAMETER: -PreventChanges
    Should the end-user be able to modify this setting after it's been set with this script?
.EXAMPLE
    -PreventChanges
    
    WARNING: Hiding News and Interests from the taskbar for all users!
    Set Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Dsh\AllowNewsAndInterests to 0
    WARNING: This script will take effect the next time the user completes a full sign-in or restarts.

PARAMETER: -RestartExplorer
    In order for this script to take immediate effect, explorer.exe will need to be restarted.
.EXAMPLE
    -RestartExplorer

    WARNING: Hiding News and Interests from the taskbar for all users!
    Registry::HKEY_USERS\S-1-12-1-2117605486-1182246982-3318994623-3070967164\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDa changed from 1 to 0
    Registry::HKEY_USERS\S-1-5-21-4122835015-3639794443-155648563-1001\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDa changed from 1 to 0
    WARNING: Restarting Explorer.exe

.OUTPUTS
    None
.NOTES
    Minimum Supported OS: Windows 10+
    Release Notes: Initial Release
By using this script, you indicate your acceptance of the following legal terms as well as our Terms of Use at https://www.ninjaone.com/terms-of-use.
    Ownership Rights: NinjaOne owns and will continue to own all right, title, and interest in and to the script (including the copyright). NinjaOne is giving you a limited license to use the script in accordance with these legal terms. 
    Use Limitation: You may only use the script for your legitimate personal or internal business purposes, and you may not share the script with another party. 
    Republication Prohibition: Under no circumstances are you permitted to re-publish the script in any script library or website belonging to or under the control of any other software provider. 
    Warranty Disclaimer: The script is provided “as is” and “as available”, without warranty of any kind. NinjaOne makes no promise or guarantee that the script will be free from defects or that it will meet your specific needs or expectations. 
    Assumption of Risk: Your use of the script is at your own risk. You acknowledge that there are certain inherent risks in using the script, and you understand and assume each of those risks. 
    Waiver and Release: You will not hold NinjaOne responsible for any adverse or unintended consequences resulting from your use of the script, and you waive any legal or equitable rights or remedies you may have against NinjaOne relating to your use of the script. 
    EULA: If you are a NinjaOne customer, your use of the script is subject to the End User License Agreement applicable to you (EULA).
#>

[CmdletBinding()]
param (
    [Parameter()]
    [Switch]$Enable,
    [Parameter()]
    [Switch]$PreventChanges = [System.Convert]::ToBoolean($env:preventChanges),
    [Parameter()]
    [Switch]$RestartExplorer = [System.Convert]::ToBoolean($env:restartExplorer)
)

begin {
    # Grabbing dynamic script variables
    if ($env:showOrHide -and $env:showOrHide -notlike "null") { if ($env:showOrHide -eq "Show") { $Enable = $True } }

    # Check if script is running with local admin privileges.
    function Test-IsElevated {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object System.Security.Principal.WindowsPrincipal($id)
        $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    # Get a list of all the user profiles for when the script is run as System.
    function Get-UserHives {
        param (
            [Parameter()]
            [ValidateSet('AzureAD', 'DomainAndLocal', 'All')]
            [String]$Type = "All",
            [Parameter()]
            [String[]]$ExcludedUsers,
            [Parameter()]
            [switch]$IncludeDefault
        )
    
        # User account SID's follow a particular pattern depending on if they're Azure AD or a Domain account or a local "workgroup" account.
        $Patterns = switch ($Type) {
            "AzureAD" { "S-1-12-1-(\d+-?){4}$" }
            "DomainAndLocal" { "S-1-5-21-(\d+-?){4}$" }
            "All" { "S-1-12-1-(\d+-?){4}$" ; "S-1-5-21-(\d+-?){4}$" } 
        }
    
        # We'll need the NTuser.dat file to load each user's registry hive. So we grab it if their account sid matches the above pattern. 
        $UserProfiles = Foreach ($Pattern in $Patterns) { 
            Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*" |
                Where-Object { $_.PSChildName -match $Pattern } | 
                Select-Object @{Name = "SID"; Expression = { $_.PSChildName } },
                @{Name = "UserName"; Expression = { "$($_.ProfileImagePath | Split-Path -Leaf)" } }, 
                @{Name = "UserHive"; Expression = { "$($_.ProfileImagePath)\NTuser.dat" } }, 
                @{Name = "Path"; Expression = { $_.ProfileImagePath } }
        }
    
        # There are some situations where grabbing the .Default user's info is needed.
        switch ($IncludeDefault) {
            $True {
                $DefaultProfile = "" | Select-Object UserName, SID, UserHive, Path
                $DefaultProfile.UserName = "Default"
                $DefaultProfile.SID = "DefaultProfile"
                $DefaultProfile.Userhive = "$env:SystemDrive\Users\Default\NTUSER.DAT"
                $DefaultProfile.Path = "C:\Users\Default"
    
                $DefaultProfile | Where-Object { $ExcludedUsers -notcontains $_.UserName }
            }
        }
    
        $UserProfiles | Where-Object { $ExcludedUsers -notcontains $_.UserName }
    }

    # Helper function for setting registry keys
    function Set-RegKey {
        param (
            $Path,
            $Name,
            $Value,
            [ValidateSet("DWord", "QWord", "String", "ExpandedString", "Binary", "MultiString", "Unknown")]
            $PropertyType = "DWord"
        )
        if (-not $(Test-Path -Path $Path)) {
            # Check if path does not exist and create the path
            New-Item -Path $Path -Force | Out-Null
        }
        if ((Get-ItemProperty -Path $Path -Name $Name -ErrorAction Ignore)) {
            # Update property and print out what it was changed from and changed to
            $CurrentValue = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Ignore).$Name
            try {
                Set-ItemProperty -Path $Path -Name $Name -Value $Value -Force -Confirm:$false -ErrorAction Stop | Out-Null
            }
            catch {
                Write-Error "[Error] Unable to Set registry key for $Name please see below error!"
                Write-Error $_
                exit 1
            }
            Write-Host "$Path\$Name changed from $CurrentValue to $($(Get-ItemProperty -Path $Path -Name $Name -ErrorAction Ignore).$Name)"
        }
        else {
            # Create property with value
            try {
                New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $PropertyType -Force -Confirm:$false -ErrorAction Stop | Out-Null
            }
            catch {
                Write-Error "[Error] Unable to Set registry key for $Name please see below error!"
                Write-Error $_
                exit 1
            }
            Write-Host "Set $Path\$Name to $($(Get-ItemProperty -Path $Path -Name $Name -ErrorAction Ignore).$Name)"
        }
    }

    # Restarts explorer.exe
    function Reset-Explorer {
        Write-Warning "Restarting Explorer.exe"
        
        Start-Sleep -Seconds 1
        Get-Process explorer | Stop-Process -Force
        Start-Sleep -Seconds 1

        if (-not (Get-Process explorer)) {
            Start-Process explorer.exe
        }
    }
    
    # Gets the OS Name E.g. Windows 10 Enterprise or Windows 11 Enterprise
    function Get-OSName {
        systeminfo | findstr /B /C:"OS Name"
    }

    $OSName = Get-OSName
}
process {
    if (-not (Test-IsElevated)) {
        Write-Error -Message "Access Denied." -RecommendedAction "Please run with Administrator privileges." -Exception (New-Object -TypeName System.UnauthorizedAccessException) -Category PermissionDenied
        exit 1
    }

    # The registry key is different depending on if its Windows 10 or Windows 11
    if ($OSName -Like "*11*") {
        $AllUserPath = (Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Dsh" -ErrorAction Ignore).AllowNewsAndInterests
    }
    else {
        $AllUserPath = (Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" -ErrorAction Ignore).EnableFeeds
    }

    # Issues a warning prior to removing the registry key that prevents changes from end-users
    if ($AllUserPath -ge 0) {
        $EnableOrDisable = switch ($AllUserPath) {
            1 { "revealed" }
            default { "hidden" }
        }

        if (-not ($PreventChanges)) {
            Write-Warning "News and Interests is currently $EnableOrDisable for all users. Removing 'Prevent Changes' setting to replace it with individual user setting as requested."
            
            if ($OSName -Like "*11*") {
                Remove-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests"
            }
            else {
                Remove-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" -Name "EnableFeeds"
            }
        }
    }

    if ($OSName -Like "*11*") {
        $KeyPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Dsh"
        $KeyName = "AllowNewsAndInterests"
        $Value = if ($Enable) { 1 }else { 0 }
    }
    else {
        $KeyPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds"
        $KeyName = "EnableFeeds"
        $Value = if ($Enable) { 1 }else { 0 }
    }

    # Sets a per user registry key if the end-user lock isn't set
    if (-not ($PreventChanges)) {
        $UserProfiles = Get-UserHives -Type "All"

        $KeyPath = New-Object System.Collections.Generic.List[string]
        $LoadedProfiles = New-Object System.Collections.Generic.List[Object]

        Foreach ($UserProfile in $UserProfiles) {
            # Load User ntuser.dat if it's not already loaded
            If ((Test-Path "Registry::HKEY_USERS\$($UserProfile.SID)" -ErrorAction Ignore) -eq $false) {
                $LoadedProfiles.Add($UserProfile)
                Start-Process -FilePath "cmd.exe" -ArgumentList "/C reg.exe LOAD HKU\$($UserProfile.SID) `"$($UserProfile.UserHive)`"" -Wait -WindowStyle Hidden
            }
            if ($OSName -Like "*11*") {
                $KeyPath.Add("Registry::HKEY_USERS\$($UserProfile.SID)\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced")
            }
            else {
                $KeyPath.Add("Registry::HKEY_USERS\$($UserProfile.SID)\Software\Microsoft\Windows\CurrentVersion\Feeds")
            }
        }

        if ($OSName -Like "*11*") {
            $KeyName = "TaskbarDa"
            $Value = if ($Enable) { 1 }else { 0 }
        }
        else {
            $KeyName = "ShellFeedsTaskbarViewMode"
            $Value = if ($Enable) { 0 }else { 2 }
        }
    }

    # Change the message depending on if we're hiding or showing the menu
    if ($Enable) {
        Write-Host "Revealing News and Interests for all users!"
    }
    else {
        Write-Warning "Hiding News and Interests from the taskbar for all users!"
    }
    
    # Setting the registry key
    $KeyPath | ForEach-Object { Set-RegKey -Path $_ -Name $KeyName -Value $Value }

    # Unload any profiles we loaded up earlier (if any)
    Foreach ($LoadedProfile in $LoadedProfiles) {
        [gc]::Collect()
        Start-Sleep 1
        Start-Process -FilePath "cmd.exe" -ArgumentList "/C reg.exe UNLOAD HKU\$($LoadedProfile.SID)" -Wait -WindowStyle Hidden | Out-Null
    }

    # Restart explorer.exe
    if ($RestartExplorer) {
        Reset-Explorer
    }
    else {
        Write-Warning "This script will take effect the next time the user completes a full sign-in or restarts."
    }
}
end {
    
    
    
}