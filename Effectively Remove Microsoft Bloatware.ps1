#Requires -Version 5.1

<#
.SYNOPSIS
    Removes common bloatware that is often pre-installed on a PC.
.DESCRIPTION
    Removes common bloatware that is often pre-installed on a PC.
.EXAMPLE
    -AppsToRemove "Amazon.com.Amazon, AmazonVideo.PrimeVideo, Clipchamp.Clipchamp, Disney.37853FC22B2CE, DropboxInc.Dropbox, Facebook.Facebook, Facebook.InstagramBeta, king.com.BubbleWitch3Saga, king.com.CandyCrushSaga, king.com.CandyCrushSodaSaga, 5A894077.McAfeeSecurity, 4DF9E0F8.Netflix, SpotifyAB.SpotifyMusic, BytedancePte.Ltd.TikTok, 5319275A.WhatsAppDesktop"
    
    [Warn] Amazon.com.Amazon is not installed!
    Attempting to remove AmazonVideo.PrimeVideo...
    Successfully removed AmazonVideo.PrimeVideo.
    Attempting to remove Clipchamp.Clipchamp...
    Successfully removed Clipchamp.Clipchamp.
    Attempting to remove Disney.37853FC22B2CE...
    Successfully removed Disney.37853FC22B2CE.
    Attempting to remove DropboxInc.Dropbox...
    Successfully removed DropboxInc.Dropbox.
    Attempting to remove FACEBOOK.FACEBOOK...
    Successfully removed FACEBOOK.FACEBOOK.
    Attempting to remove Facebook.InstagramBeta...
    Successfully removed Facebook.InstagramBeta.
    [Warn] king.com.BubbleWitch3Saga is not installed!
    [Warn] king.com.CandyCrushSaga is not installed!
    [Warn] king.com.CandyCrushSodaSaga is not installed!
    Attempting to remove 5A894077.McAfeeSecurity...
    Successfully removed 5A894077.McAfeeSecurity.
    Attempting to remove 4DF9E0F8.Netflix...
    Successfully removed 4DF9E0F8.Netflix.
    Attempting to remove SpotifyAB.SpotifyMusic...
    Successfully removed SpotifyAB.SpotifyMusic.
    Attempting to remove BytedancePte.Ltd.TikTok...
    Successfully removed BytedancePte.Ltd.TikTok.
    Attempting to remove 5319275A.WhatsAppDesktop...
    Successfully removed 5319275A.WhatsAppDesktop.

PARAMETER: -AppsToRemove "AmazonVideo.PrimeVideo"
    A comma-separated list of Appx package names you would like to remove.

PARAMETER: -OverrideWithCustomField "ReplaceMeWithAmultilineCustomFieldName"
    Name of a multiline custom field to retrieve the 'Apps To Remove' list.

.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
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
    [String]$AppsToRemove = "Amazon.com.Amazon, AmazonVideo.PrimeVideo, Clipchamp.Clipchamp, Disney.37853FC22B2CE, DropboxInc.Dropbox, Facebook.Facebook, Facebook.InstagramBeta, king.com.BubbleWitch3Saga, king.com.CandyCrushSaga, king.com.CandyCrushSodaSaga, 5A894077.McAfeeSecurity, 4DF9E0F8.Netflix, SpotifyAB.SpotifyMusic, BytedancePte.Ltd.TikTok, 5319275A.WhatsAppDesktop",
    [Parameter()]
    [String]$OverrideWithCustomField
)

begin {
    # Replace parameters with dynamic script variables.
    if ($env:appsToRemove -and $env:appsToRemove -notlike "null") { $AppsToRemove = $env:appsToRemove }
    if ($env:overrideWithCustomFieldName -and $env:overrideWithCustomFieldName -notlike "null") { $OverrideWithCustomField = $env:overrideWithCustomFieldName }

    $AppList = New-Object System.Collections.Generic.List[string]

    function Get-NinjaProperty {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
            [String]$Name
        )
    
        # We'll redirect error output to the success stream to make it easier to error out if nothing was found or something else went wrong.
        $NinjaPropertyValue = Ninja-Property-Get -Name $Name 2>&1
    
        # If we received some sort of error it should have an exception property and we'll exit the function with that error information.
        if ($NinjaPropertyValue.Exception) { throw $NinjaPropertyValue }
    
        if (-not $NinjaPropertyValue) {
            throw [System.NullReferenceException]::New("The Custom Field '$Name' is empty!")
        }
    
        $NinjaPropertyValue
    }

    if ($OverrideWithCustomField) {
        Write-Host "Attempting to retrieve uninstall list from '$OverrideWithCustomField'."
        try {
            $AppsToRemove = Get-NinjaProperty -Name $OverrideWithCustomField -ErrorAction Stop
        }
        catch {
            # If we ran into some sort of error we'll output it here.
            Write-Host "[Error] $($_.Exception.Message)"
            exit 1
        }
    }

    # Check if apps to remove are specified; otherwise, list all Appx packages and exit
    if (!$AppsToRemove) {
        Write-Host "[Error] Nothing given to remove? Please specify one of the below packages."
        Get-AppxPackage -AllUsers | Select-Object Name | Sort-Object Name | Out-String | Write-Host
        exit 1
    }

    # Regex to detect invalid characters in Appx package names
    $InvalidCharacters = "[#!@&$)(<>?|:;\/{}^%`"']+"

    # Process each app name after splitting the input string
    if ($AppsToRemove -match ",") {
        $AppsToRemove -split ',' | ForEach-Object {
            $App = $_.Trim()
            if ($App -match '^[-.]' -or $App -match '\.\.|--' -or $App -match '[-.]$' -or $App -match "\s" -or $App -match $InvalidCharacters) {
                Write-Host "[Error] Invalid character in '$App'. Appx package names cannot contain '#!@&$)(<>?|:;\/{}^%`"'', start with '.-', contain a space, or have consecutive '.' or '-' characters."
                $ExitCode = 1
                return
            }

            if ($App.Length -ge 50) {
                Write-Host "[Error] Appx package name of '$App' is invalid Appx package names must be less than 50 characters."
                $ExitCode = 1
                return
            }

            $AppList.Add($App)
        }
    }
    else {
        $AppsToRemove = $AppsToRemove.Trim()
        if ($AppsToRemove -match '^[-.]' -or $AppsToRemove -match '\.\.|--' -or $AppsToRemove -match '[-.]$' -or $AppsToRemove -match "\s" -or $AppsToRemove -match $InvalidCharacters) {
            Write-Host "[Error] Invalid character in '$AppsToRemove'. AppxPackage names cannot contain '#!@&$)(<>?|:;\/{}^%`"'', start with '.-', contain a space, or have consecutive '.' or '-' characters."
            Get-AppxPackage -AllUsers | Select-Object Name | Sort-Object Name | Out-String | Write-Host
            exit 1
        }

        if ($AppsToRemove.Length -ge 50) {
            Write-Host "[Error] Appx package name of '$AppsToRemove' is invalid Appx package names must be less than 50 characters."
            Get-AppxPackage -AllUsers | Select-Object Name | Sort-Object Name | Out-String | Write-Host
            exit 1
        }

        $AppList.Add($AppsToRemove)
    }

    # Exit if no valid apps to remove
    if ($AppList.Count -eq 0) {
        Write-Host "[Error] No valid apps to remove!"
        Get-AppxPackage -AllUsers | Select-Object Name | Sort-Object Name | Out-String | Write-Host
        exit 1
    }

    # Function to check if the script is running with Administrator privileges
    function Test-IsElevated {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object System.Security.Principal.WindowsPrincipal($id)
        $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    if (!$ExitCode) {
        $ExitCode = 0
    }
}
process {
    # Check for Administrator privileges before attempting to remove any packages
    if (!(Test-IsElevated)) {
        Write-Host -Object "[Error] Access Denied. Please run with Administrator privileges."
        exit 1
    }

    # Attempt to remove each specified app
    foreach ($App in $AppList) {
        $AppxPackage = Get-AppxPackage -AllUsers | Where-Object { $_.Name -Like "*$App*" } | Sort-Object Name -Unique
        $ProvisionedPackage = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*$App*" } | Sort-Object DisplayName -Unique
        
        # Warn if the app is not installed
        if (!$AppxPackage -and !$ProvisionedPackage) {
            Write-Host "`n[Warn] $App is not installed!"
            continue
        }

        # Output an error if too many apps were selected for uninstall
        if ($AppxPackage.Count -gt 1) {
            Write-Host "[Error] Too many Apps were found with the name '$App'. Please re-run with a more specific name."
            Write-Host ($AppxPackage | Select-Object Name | Sort-Object Name | Out-String)
            $ExitCode = 1
            continue
        }
        if ($ProvisionedPackage.Count -gt 1) {
            Write-Host "[Error] Too many Apps were found with the name '$App'. Please re-run with a more specific name."
            Write-Host ($ProvisionedPackage | Select-Object DisplayName | Sort-Object DisplayName | Out-String)
            ExitCode = 1
            continue
        }

        # Output an error if two different packages got selected.
        if ($ProvisionedPackage -and $AppxPackage -and $AppxPackage.Name -ne $ProvisionedPackage.DisplayName) {
            Write-Host "[Error] Too many Apps were found with the name '$App'. Please re-run with a more specific name."
            Write-Host ($ProvisionedPackage | Select-Object DisplayName | Sort-Object DisplayName | Out-String)
            ExitCode = 1
            continue
        }

        try {
            # Remove the provisioning package first.
            if ($ProvisionedPackage) {
                Write-Host "`nAttempting to remove provisioning package $($ProvisionedPackage.DisplayName)..."
                Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*$App*" } | Remove-AppxProvisionedPackage -Online -AllUsers | Out-Null
                Write-Host "Successfully removed provisioning package $($ProvisionedPackage.DisplayName)."
            }

            # Remove the installed instances.
            if ($AppxPackage) {
                Write-Host "`nAttempting to remove $($AppxPackage.Name)..."
                Get-AppxPackage -AllUsers | Where-Object { $_.Name -Like "*$App*" } | Remove-AppxPackage -AllUsers
                Write-Host "Successfully removed $($AppxPackage.Name)."
            }
        }
        catch {
            Write-Host "[Error] $($_.Exception.Message)"
            $ExitCode = 1
        }
    }

    exit $ExitCode
}
end {
    
    
    
}