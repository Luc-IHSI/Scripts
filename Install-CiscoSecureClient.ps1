<#
    Installs Cisco Secure Client components: DART, AnyConnect VPN, Umbrella.

    The script performs the following steps:
    1. Validates whether each required component is installed and at the correct version.
    2. Downloads the necessary installer files if they are not found.
    3. Installs or upgrades the components, ensuring each installation is done silently and without user interaction.
    4. Imports configuration certificates for the Umbrella module.
    5. Copies VPN profile configurations if provided.
    6. Cleans up the temporary installation directory once completed.

#.PARAMETER Version
    Specifies the version of the Cisco Secure Client to install. If not provided, it defaults to the value from the environment variable `$env:version`.

#.PARAMETER Client
    Specifies the client code. If not provided, it defaults to the value from the environment variable `$env:clientCode`.

#.PARAMETER GetDart
    A flag to install the DART. Defaults to the value from `$env:diagnosticsAndReportingTool`.

#.PARAMETER GetUmbrella
    A flag to install the Umbrella module. Defaults to the value from `$env:umbrella`.

#.PARAMETER GetVPN
    A flag to install the AnyConnect VPN module. Defaults to the value from `$env:anyconnectVpn`
#>

#    msiexec /i Setup.msi /qn ORG_ID=8308574 ORG_FINGERPRINT=1aa126279a979410e5bc66063a4b4d02 USER_ID=12702307 HIDE_UI=1 HIDE_ARP=1

#region PARAM_VAR ----------------------------------------------------------------------------------------------------------

param(
	[Version]$Version    = $env:version,
	[string]$Client      = $env:clientCode,
	[string]$GetDart     = $env:diagnosticsAndReportingTool,
	[string]$GetUmbrella = $env:umbrella,
	[string]$GetVPN      = $env:anyconnectVpn
)

$WarningPreference = 'SilentlyContinue'
$TempDir           = 'C:\Temp\CiscoSecureClient'
$URL               = "https://github.com/Luc-IHSI/CiscoUmbrella/blob/main/IHSI.zip"

$Dart = [PSCustomObject]@{
    Name = 'Cisco Secure Client - Diagnostics and Reporting Tool'
    MSI  = "cisco-secure-client-win-$Version-dart-predeploy-k9.msi"
    Path = Join-Path -Path $TempDir -ChildPath "cisco-secure-client-win-$Version-dart-predeploy-k9.msi"
    Arg  = "/i $(Join-Path -Path $TempDir -ChildPath "cisco-secure-client-win-$Version-dart-predeploy-k9.msi") /norestart /quiet /l*v $TempDir\Dart.log"
}
$Umbrella = [PSCustomObject]@{
    Name = 'Cisco Secure Client - Umbrella'
    MSI  = "cisco-secure-client-win-$Version-umbrella-predeploy-k9.msi"
    Path = Join-Path -Path $TempDir -ChildPath "cisco-secure-client-win-$Version-umbrella-predeploy-k9.msi"
    Arg  = "/i $(Join-Path -Path $TempDir -ChildPath "cisco-secure-client-win-$Version-umbrella-predeploy-k9.msi") /norestart /quiet /l*v $TempDir\Umbrella.log"
}
$VPN = [PSCustomObject]@{
    Name = 'Cisco Secure Client - AnyConnect VPN'
    MSI  = "cisco-secure-client-win-$Version-core-vpn-predeploy-k9.msi"
    Path = Join-Path -Path $TempDir -ChildPath "cisco-secure-client-win-$Version-core-vpn-predeploy-k9.msi"
    Arg  = "/i $(Join-Path -Path $TempDir -ChildPath "cisco-secure-client-win-$Version-core-vpn-predeploy-k9.msi") /norestart /quiet $(if (!($GetVPN -eq 'true')) {'PRE_DEPLOY_DISABLE_VPN=1'}) /l*v $TempDir\VPN.log"
}

#endregion -----------------------------------------------------------------------------------------------------------------	

#region FUNCTIONS ----------------------------------------------------------------------------------------------------------

function Test-App {

	#region LOGIC ----------------------------------------------------------------------------------------------------------
	<#
	[SUMMARY]
	Tests if an application is installed and if it is, checks if it is on the correct version.

	[PARAMETERS]
	- $App: The application to test using its name value querying Get-Package.

	[LOGIC]
	1. Get the installed version of the app using Get-Package.
    2. If $script:InstallAttempted is $true, check if the app is installed and output results to console.
	3. If $script:InstallAttempted is $false/undefined, check if the app is installed and output results to console.
	4. If the app is not installed, install it, otherwise if the app is not on the correct version, upgrade it.
	#>
	#endregion -------------------------------------------------------------------------------------------------------------

	param (
		[PSCustomObject]$App
	)

	$AppInstall = Get-Package $App.Name -EA SilentlyContinue

	if ($script:InstallAttempted -eq $true) {
		if ($AppInstall) {
			if ([Version]$AppInstall.Version -ne [Version]$Version) { 
				Write-Host "[FAIL] $($App.Name) has not been installed/upgraded, please attempt manual install/upgrade." ; $script:InstallAttempted = $false
			} else {
				Write-Host "[PASS] $(if (!($GetVPN -eq 'true') -and ($App.Name -like '*VPN*')) {'Cisco Secure Client'} else {$($App.Name)}) has been installed/upgraded and is on version $Version." ; $script:InstallAttempted = $false
			}
		} else {
			Write-Host "[FAIL] $($App.Name) has not been installed/upgraded, please attempt manual install/upgrade." ; $script:InstallAttempted = $false
		}
	} else {
		if ($AppInstall) {
			if ([Version]$AppInstall.Version -ne [Version]$Version) { 
				Write-Host "[INFO] $($App.Name) is on $($AppInstall.Version), upgrading to $Version." ; Install-App -App $App
			} else {
				Write-Host "[PASS] $($App.Name) is on the latest version."
			}
		} else {
			Write-Host "[INFO] $($App.Name) is not installed, starting installation." ; Install-App -App $App
		}
	}
}

function Install-App {

	#region LOGIC ----------------------------------------------------------------------------------------------------------
	<#
	[SUMMARY]
	Installs an application using the installer file.

	[PARAMETERS]
	- $App: The application to install.

	[LOGIC]
	1. If the installer file does not exist, download the file.
	2. Install the application.
	3. If the application is Umbrella, import the configuration certificate.
	4. Set the $script:InstallAttempted variable to $true.
	5. Test the application.
	#>
	#endregion -------------------------------------------------------------------------------------------------------------

	param (
		[PSCustomObject]$App
	)

	if (!(Test-Path -Path $TempDir/$Client-$Version.zip)) { 
		if (!(Test-Path -Path $TempDir)) { Set-Dir -Path $TempDir -Create }
		Get-File -URL $URL -Path $TempDir/"$Client-$Version.zip" }

	try {
		Write-Host "[INFO] Installing $(if (!($GetVPN -eq 'true') -and ($App.Name -like '*VPN*')) {'Cisco Secure Client'} else {$($App.Name)})."
		Start-Process msiexec.exe -ArgumentList $App.Arg -Wait
		if ($App.Name -eq 'Cisco Secure Client - Umbrella') { Import-ConfigCert }
		if ($App.Name -eq 'Cisco Secure Client - AnyConnect VPN') {
			if (Test-Path $TempDir\Profile.xml) {
				try {
					$VPNProfile = 'C:\ProgramData\Cisco\Cisco Secure Client\VPN\Profile\Profile.xml'
					Copy-Item -Path $TempDir\Profile.xml -Destination $VPNProfile -EA Stop | Out-Null
					Write-Host "[PASS] VPN Profile copied to $($VPNProfile.Split('\')[-1])."
				} catch {
					Write-Host "[FAIL] Failed to copy VPN Profile to $($VPNProfile.Split('\')[-1]). $($_.Exception.Message)"
				}
			}
		}
		$script:InstallAttempted = $true
		Test-App -App $App
	} catch {
		Write-Host "[FAIL] $($_.Exception.Message)"
	}
}

#endregion -----------------------------------------------------------------------------------------------------------------

#region ANCILLARY_FUNCTIONS ------------------------------------------------------------------------------------------------

function Get-File {

    #region LOGIC -----------------------------------------------------------------------------------------------------------
    <#
    [SUMMARY]
    Downloads a file from a specified URL/UNC path and saves it to a specified destination.

    [PARAMETERS]
    - $UNC: If declared, copy the file from a UNC path.
    - $URL: The URL of the file to download.
    - $Path: The path to save the file to.

    [LOGIC]
    1. Set the $ProgressPreference variable to 'SilentlyContinue'.
    2. Set an array of download methods.
    3. Set the Security Protocols.
    4. Check if $UNC is declared, otherwise skip that download method.
    5. Try each download method, if successful, break out of the loop.
    6. If the file extension is .zip, extract the archive to the Destination directory.
    7. If all download methods fail, throw an error.
    #>
    #endregion -------------------------------------------------------------------------------------------------------------

    param (
        [string]$UNC,
        [string]$URL,
        [string]$Path
    )

    $ProgressPreference = 'SilentlyContinue'

    # Set array for download methods
    $DownloadMethods = @(
        @{ Name = "copying from UNC Path"; Action = { Copy-Item -Path $UNC -Destination $Path -Force -EA Stop }},
        @{ Name = "Invoke-WebRequest"; Action = { Invoke-WebRequest -Uri $URL -OutFile $Path -EA Stop }},
        @{ Name = "Start-BitsTransfer"; Action = { Start-BitsTransfer -Source $URL -Destination $Path -EA Stop }},
        @{ Name = "WebClient"; Action = { (New-Object System.Net.WebClient).DownloadFile($URL, $Path) }}
    )
    
    # Set Security Protocols
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls13 -bor
												  [Net.SecurityProtocolType]::Tls12 -bor
                                                  [Net.SecurityProtocolType]::Tls11 -bor
                                                  [Net.SecurityProtocolType]::Tls

    # Loop through each download method
    foreach ($Method in $DownloadMethods) {
        if ($Method.Name -eq "copying from UNC Path") {if (-not $UNC -or -not (Test-Path -Path $UNC @EA_Silent)) { continue } }
        try {
            Write-Host "[INFO] Attempting to download by $($Method.Name)."
            & $Method.Action
            Write-Host "[PASS] Download completed by $($Method.Name)."
            $Downloaded = $true
            # Extract archive if file extension ends in .zip
            if ($Path -like "*.zip") {
                Write-Host "[INFO] Extracting $Path."
                Expand-Archive -LiteralPath $Path -DestinationPath $TempDir -Force -EA Stop
                Write-Host "[PASS] Extraction complete."
            }
            break
        } catch {
            Write-Host "[FAIL] Failed to download by $($Method.Name). $($_.Exception.Message)"
        }
    }

    # Terminate script if all $DownloadMethods fail
    if (-not $Downloaded) { throw "[FAIL] All download methods failed, terminating script." }
}

function Import-ConfigCert {

	#region LOGIC -----------------------------------------------------------------------------------------------------------
	<#
	[SUMMARY]
	Imports a configuration and certificate for the Cisco Secure Client.

	[LOGIC]
	1. Set the directory for the Cisco Secure Client.
	2. Copy the configuration file to the directory.
	3. Import the certificate to the local machine.
	#>
	#endregion -------------------------------------------------------------------------------------------------------------

	try {
		Set-Dir -Path 'C:\ProgramData\Cisco\Cisco Secure Client\Umbrella' -Create
		Copy-Item -Path "$TempDir\OrgInfo.json" -Destination "C:\ProgramData\Cisco\Cisco Secure Client\Umbrella\OrgInfo.json" -EA Stop | Out-Null
		Import-Certificate -FilePath "$TempDir\Cisco_Umbrella_Root_CA.cer" -CertStoreLocation Cert:\LocalMachine\Root -EA Stop | Out-Null
		Write-Host "[PASS] Umbrella configuration and certificate imported."
	} catch {
		Write-Host "[FAIL] $($_.Exception.Message)"
	}
}

function Set-Dir {

    #region LOGIC -----------------------------------------------------------------------------------------------------------
    <#
    [SUMMARY]
    Creates or deletes a directory at a specified path.

    [PARAMETERS]
    - $Path: The path to create or delete the directory at.
    - $Create: If declared, create the directory.
    - $Remove: If declared, delete the directory.

    [LOGIC]
    1. Check if both $Create and $Remove switches are not declared, if so, throw an error.
    2. Create or delete the directory based on the switches and whether the directory exists.
    3. Throw an error if the directory cannot be created or deleted.
    #>
    #endregion -------------------------------------------------------------------------------------------------------------

    param (
        [string]$Path,
        [switch]$Create,
        [switch]$Remove
    )

    if (-not $Create.IsPresent -and -not $Remove.IsPresent) {
        Write-Host "[FAIL] Must declare -Create or -Remove switch with Set-Dir function." ; exit
    }

    switch ($true) {
        { $Create.IsPresent } {
            if (-not (Test-Path -Path $Path)) {
                try {
                    Write-Host "[INFO] Creating directory at $Path"
                    New-Item -Path $Path -ItemType "Directory" | Out-Null
                    Write-Host "[PASS] Created directory at $Path."
                } catch {
                    Write-Host "[FAIL] Failed to create directory. $($_.Exception.Message)"
                }
            } else {
                Write-Host "[INFO] Directory exists at $Path"
            }
        }
        { $Remove.IsPresent } {
            try {
                Write-Host "[INFO] Deleting directory."
                Remove-Item -Path $Path -Recurse -Force -EA Stop
                Write-Host "[PASS] Directory deleted."
            } catch {
                Write-Host "[FAIL] Failed to remove directory. $($_.Exception.Message)"
            }
        }
    }
}

#endregion -----------------------------------------------------------------------------------------------------------------	

#region EXECUTIONS ---------------------------------------------------------------------------------------------------------

if ($GetDart -eq 'true') { Test-App -App $Dart }
if ($GetVPN -eq 'true') { Test-App -App $VPN }
if ($GetUmbrella -eq 'true') {
	Write-Host "[INFO] Checking for Core module requirement before installing $($Umbrella.Name)."
	if (!(Get-Package $VPN.Name -EA SilentlyContinue)) { Write-Host "[INFO] Core module requirement for $($Umbrella.Name) not found, starting installation." ; Install-App -App $VPN }
	else { Write-Host "[PASS] Core module requirement for $($Umbrella.Name) found, continuing with installation." ; Test-App -App $Umbrella }
}
if (Test-Path -Path $TempDir) { Set-Dir -Path $TempDir -Remove }

#endregion -----------------------------------------------------------------------------------------------------------------