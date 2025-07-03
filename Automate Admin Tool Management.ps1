#Requires -Version 5.1

<#
.SYNOPSIS
    This will enable the selected administrator tools depending on your selection (Defaults to all). Can be given a comma seperated list/string of tools to be enabled.
    Can also be given a comma seperated list of users to exclude from this action. Full Options: "All", "Cmd", "ControlPanel", "MMC", "RegistryEditor", "Run", "TaskMgr"
.DESCRIPTION
    This will enable the selected administrator tools. The options are "All", the command prompt, the control panel, the microsoft management console,
    the registry editor, the run command window and task manager. You can give it a comma seperated list of items if you want to enable some but not all.
    Exit 1 is usually an indicator of bad input but can also mean editing the registry is blocked.
.EXAMPLE
    PS C:> .Enable-LocalAdminTools.ps1 -Tools "MMC,Cmd,TaskMgr,RegistryEditor"
    Enabling MMC...
    Set Registry::HKEY_USERSDefaultProfileSoftwarePoliciesMicrosoftMMCRestrictToPermittedSnapins to...
    Enabling Cmd...
    Set Registry::HKEY_USERSDefaultProfileSoftwarePoliciesMicrosoftWindowsDisableCMD to...
    Enabling TaskMgr...
    Set Registry::HKEY_USERSDefaultProfileSoftwareMicrosoftWindowsCurrentVersionPoliciesSystemDisableTaskMgr to...
    Enabling RegistryEditor...
    Set Registry::HKEY_USERSDefaultProfileSoftwareMicrosoftWindowsCurrentVersionPoliciesSystemDisableRegistryTools to...
.OUTPUTS
    None
.NOTES
    General notes: Will set the regkeys for users created after this script is ran.
    Release Notes:
    Initial Release
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
    [String]$Tools = "All",
    [Parameter()]
    [String]$ExcludedUsers
)

begin {
    # Lets double check that this script is being run appropriately
    function Test-IsElevated {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object System.Security.Principal.WindowsPrincipal($id)
        $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    function Test-IsSystem {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        return $id.Name -like "NT AUTHORITY*" -or $id.IsSystem
    }

    if (!(Test-IsElevated) -and !(Test-IsSystem)) {
        Write-Error -Message "[Error] Access Denied. Please run with Administrator privileges."
        exit 1
    }

    # Setting up some functions to be used later.
    function Set-HKProperty {
        param (
            $Path,
            $Name,
            $Value,
            [ValidateSet('DWord', 'QWord', 'String', 'ExpandedString', 'Binary', 'MultiString', 'Unknown')]
            $PropertyType = 'DWord'
        )
        if (-not $(Test-Path -Path $Path)) {
            # Check if path does not exist and create the path
            New-Item -Path $Path -Force | Out-Null
        }
        if ((Get-ItemProperty -Path $Path -Name $Name -ErrorAction Ignore)) {
            # Update property and print out what it was changed from and changed to
            $CurrentValue = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Ignore
            try {
                Set-ItemProperty -Path $Path -Name $Name -Value $Value -Force -Confirm:$false -ErrorAction Stop | Out-Null
            }
            catch {
                Write-Error "[Error] Unable to Set registry key for $Name please see below error!"
                Write-Error $_
                exit 1
            }
            Write-Host "$Path$Name changed from $CurrentValue to $(Get-ItemProperty -Path $Path -Name $Name -ErrorAction Ignore)"
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
            Write-Host "Set $Path$Name to $(Get-ItemProperty -Path $Path -Name $Name -ErrorAction Ignore)"
        }
    }

    # This will get all the registry path's for all actual users (not system or network service account but actual users.)
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

        # User account SID's follow a particular patter depending on if they're azure AD or a Domain account or a local "workgroup" account.
        $Patterns = switch ($Type) {
            "AzureAD" { "S-1-12-1-(d+-?){4}$" }
            "DomainAndLocal" { "S-1-5-21-(d+-?){4}$" }
            "All" { "S-1-12-1-(d+-?){4}$" ; "S-1-5-21-(d+-?){4}$" } 
        }

        # We'll need the NTuser.dat file to load each users registry hive. So we grab it if their account sid matches the above pattern. 
        $UserProfiles = Foreach ($Pattern in $Patterns) { 
            Get-ItemProperty "HKLM:SOFTWAREMicrosoftWindows NTCurrentVersionProfileList*" |
                Where-Object { $_.PSChildName -match $Pattern } | 
                Select-Object @{Name = "SID"; Expression = { $_.PSChildName } }, 
                @{Name = "UserHive"; Expression = { "$($_.ProfileImagePath)NTuser.dat" } }, 
                @{Name = "UserName"; Expression = { "$($_.ProfileImagePath | Split-Path -Leaf)" } }
        }

        # There are some situations where grabbing the .Default user's info is needed.
        switch ($IncludeDefault) {
            $True {
                $DefaultProfile = "" | Select-Object UserName, SID, UserHive
                $DefaultProfile.UserName = "Default"
                $DefaultProfile.SID = "DefaultProfile"
                $DefaultProfile.Userhive = "$env:SystemDriveUsersDefaultNTUSER.DAT"

                # It was easier to write-output twice than combine the two objects.
                $DefaultProfile | Where-Object { $ExcludedUsers -notcontains $_.UserName } | Write-Output
            }
        }

        $UserProfiles | Where-Object { $ExcludedUsers -notcontains $_.UserName } | Write-Output
    }

    function Set-Tool {
        [CmdletBinding()]
        param(
            [Parameter()]
            [ValidateSet("All", "Cmd", "ControlPanel", "MMC", "RegistryEditor", "Run", "TaskMgr")]
            [string]$Tool,
            [string]$key
        )
        process {
            # Each option has a different registry key to change. Since this function only supports 1 item at a time I can check which option and set the regkey individually.
            Write-Host "Enabling $Tool..."
            switch ($Tool) {
                "Cmd" { Set-HKProperty -Path $keySoftwarePoliciesMicrosoftWindowsSystem -Name DisableCMD -Value 0 }
                "ControlPanel" { Set-HKProperty -Path $keySoftwareMicrosoftWindowsCurrentVersionPoliciesExplorer -Name NoControlPanel -Value 0 }
                "MMC" { Set-HKProperty -Path $keySoftwarePoliciesMicrosoftMMC -Name RestrictToPermittedSnapins -Value 0 }
                "RegistryEditor" { Set-HKProperty -Path $keySoftwareMicrosoftWindowsCurrentVersionPoliciesSystem -Name DisableRegistryTools -Value 0 }
                "Run" { Set-HKProperty -Path $keySoftwareMicrosoftWindowsCurrentVersionPoliciesExplorer -Name NoRun -Value 0 }
                "TaskMgr" { Set-HKProperty -Path $keySoftwareMicrosoftWindowsCurrentVersionPoliciesSystem -Name DisableTaskMgr -Value 0 }
                "All" {
                    Set-HKProperty -Path $keySoftwarePoliciesMicrosoftWindowsSystem -Name DisableCMD -Value 0
                    Set-HKProperty -Path $keySoftwareMicrosoftWindowsCurrentVersionPoliciesSystem -Name NoDispCPL -Value 0
                    Set-HKProperty -Path $keySoftwarePoliciesMicrosoftMMC -Name RestrictToPermittedSnapins -Value 0
                    Set-HKProperty -Path $keySoftwareMicrosoftWindowsCurrentVersionPoliciesSystem -Name DisableRegistryTools -Value 0
                    Set-HKProperty -Path $keySoftwareMicrosoftWindowsCurrentVersionPoliciesExplorer -Name NoRun -Value 0
                    Set-HKProperty -Path $keySoftwareMicrosoftWindowsCurrentVersionPoliciesSystem -Name DisableTaskMgr -Value 0
                }
            }
        }
    }
}
process {

    # Get each user profile SID and Path to the profile. If there are any exclusions we'll have to take them into account.
    if ($ExcludedUsers -or $env:ExcludedUsers) {
        if ($env:ExcludedUsers) {
            $ToBeExcluded = @()
            $ToBeExcluded += $env:ExcludedUsers.split(",").trim()
            Write-Warning "The Following Users will not have your selected tools disabled. $ToBeExcluded"
        }
        else {
            $ToBeExcluded = @()
            $ToBeExcluded += $ExcludedUsers.split(",").trim()
            Write-Warning "The Following Users will not have your selected tools disabled. $ToBeExcluded"
        }
        $UserProfiles = Get-UserHives -IncludeDefault -ExcludedUsers $ToBeExcluded
    }
    else {
        $UserProfiles = Get-UserHives -IncludeDefault
    }

    # Loop through each profile on the machine
    Foreach ($UserProfile in $UserProfiles) {
        # Load each user's registry hive if not already loaded. Backticked "UserProfile.UserHive" so that it accounts for spaces in the username.
        If (($ProfileWasLoaded = Test-Path Registry::HKEY_USERS$($UserProfile.SID)) -eq $false) {
            Start-Process -FilePath "cmd.exe" -ArgumentList "/C reg.exe LOAD HKU$($UserProfile.SID) `"$($UserProfile.UserHive)`"" -Wait -WindowStyle Hidden
        }
        # The path is different for each individual user. This is the base path.
        $key = "Registry::HKEY_USERS$($UserProfile.SID)"

        # List of checkbox items
        $CheckboxItems = "Cmd", "ControlPanel", "MMC", "RegistryEditor", "Run", "TaskMgr"
        # Checkboxes come in as environmental variables. This'll grab the ones that were selected (if any)
        $EnvItems = Get-ChildItem env:* | Where-Object { $CheckboxItems -contains $_.Name }

        # This will grab the tool selections from the parameter field. Since it comes in as a string we'll have to split it up.
        $Tool = $Tools.split(",").trim()

        # If the checkbox for all was selected I can just run the function once instead of running it repeatedly for the same thing.
        if ($env:All) {
            Set-Tool -Tool "All" -Key $key
        }
        elseif ($EnvItems) {
            # If checkboxes were used we should just use those.
            $EnvItems | ForEach-Object { Set-Tool -Tool $_.Name -Key $key }
        }
        else {
            $Tool | ForEach-Object { Set-Tool -Tool $_ -Key $key }
        }

        # Unload NTuser.dat for user's we loaded previously.
        If ($ProfileWasLoaded -eq $false) {
            [gc]::Collect()
            Start-Sleep -Seconds 1
            Start-Process -FilePath "cmd.exe" -ArgumentList "/C reg.exe UNLOAD HKU$($UserProfile.SID)" -Wait -WindowStyle Hidden | Out-Null
        }
    }
    
}
end {
    $ScriptVariables = @(
        [PSCustomObject]@{
            name           = "All"
            calculatedName = "all"
            required       = $false
            defaultValue   = [PSCustomObject]@{
                type  = "TEXT"
                value = $true
            }
            valueType      = "CHECKBOX"
            valueList      = $null
            description    = "All Admin Tools"
        }
        [PSCustomObject]@{
            name           = "Cmd"
            calculatedName = "cmd"
            required       = $false
            defaultValue   = $null
            valueType      = "CHECKBOX"
            valueList      = $null
            description    = "Command Prompt"
        }
        [PSCustomObject]@{
            name           = "ControlPanel"
            calculatedName = "controlpanel"
            required       = $false
            defaultValue   = $null
            valueType      = "CHECKBOX"
            valueList      = $null
            description    = "Control Panel"
        }
        [PSCustomObject]@{
            name           = "MMC"
            calculatedName = "mmc"
            required       = $false
            defaultValue   = $null
            valueType      = "CHECKBOX"
            valueList      = $null
            description    = "Microsoft Management Console"
        }
        [PSCustomObject]@{
            name           = "RegistryEditor"
            calculatedName = "registryeditor"
            required       = $false
            defaultValue   = $null
            valueType      = "CHECKBOX"
            valueList      = $null
            description    = "The Registry Editor"
        }
        [PSCustomObject]@{
            name           = "Run"
            calculatedName = "run"
            required       = $false
            defaultValue   = $null
            valueType      = "CHECKBOX"
            valueList      = $null
            description    = "Run Command Window"
        }
        [PSCustomObject]@{
            name           = "TaskMgr"
            calculatedName = "taskmgr"
            required       = $false
            defaultValue   = $null
            valueType      = "CHECKBOX"
            valueList      = $null
            description    = "Task Manager"
        }
        [PSCustomObject]@{
            name           = "ExcludedUsers"
            calculatedName = "excludedusers"
            required       = $false
            defaultValue   = $null
            valueType      = "TEXT"
            valueList      = $null
            description    = "Comma separated list of users you would like to exclude."
        }
    )
}