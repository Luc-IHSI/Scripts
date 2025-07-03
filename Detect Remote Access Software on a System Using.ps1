#Requires -Version 5.1

<#
.SYNOPSIS
    This script will look for remote access tools installed on the system. It can be given a list of tools to ignore as well as grab the exclusion list from a designated custom field.
    
    DISCLAIMER: This script is provided as a best effort for detecting remote access software installed on an agent, but it is not guaranteed to be 100% accurate. 
    Some remote access software may not be detected, or false positives may be reported. Use this script at your own risk and verify its results with other methods where possible.
.DESCRIPTION
    This script will look for remote access tools installed on the system. Below is the full list of tools. Please note you can give it a list of tools to ignore and you can have
    it grab the list from a custom field of your choosing.

    DISCLAIMER: This script is provided as a best effort for detecting remote access software installed on an agent, but it is not guaranteed to be 100% accurate. 
    Some remote access software may not be detected, or false positives may be reported. Use this script at your own risk and verify its results with other methods where possible.

    Remote Tools: AeroAdmin, Ammyy Admin, AnyDesk, BeyondTrust, Chrome Remote Desktop, Connectwise Control, DWService, GoToMyPC, LiteManager, LogMeIn, ManageEngine,
    NoMachine, Parsec, Remote Utilities, RemotePC, Splashtop, Supremo, TeamViewer, TightVNC, UltraVNC, VNC Connect (RealVNC), Zoho Assist
    RMM's: Atera, Automate, Datto RMM, Kaseya, N-Able N-Central, N-Able N-Sight, Syncro

.EXAMPLE
    (No Parameters)
    Name                    CurrentlyRunning    HasRunningService   UninstallString
    ----                    ----------------    -----------------   ---------------
    Connectwise Control     Yes                 Yes                 MsiExec /X{examplestring}
    Chrome Remote Desktop   Yes                 Yes                 MsiExec /X{examplestring}

PARAMETER: -ExcludeTools "Chrome Remote Desktop,Connectwise Control"
    A comma seperated list of tools you'd like to exclude from alerting on.
.EXAMPLE
    -ExcludeTools "Chrome Remote Desktop,Connectwise Control"
    We couldn't find any active remote access tools!

PARAMETER: -ExclusionsFromCustomField "ReplaceMeWithAnyTextCustomField"
    The name of a custom field that contains a comma seperated list of tools to exclude from alerting. ex. "ApprovedRemoteTools"
.EXAMPLE
    -ExclusionsFromCustomField "ReplaceMeWithAnyTextCustomField"
    We couldn't find any active remote access tools!

PARAMETER: -ExportCSV "ReplaceMeWithAnyMultiLineCustomField"
    The name of a multiline custom field to export to in csv format. ex. "RemoteTools"
.EXAMPLE
    -ExportCSV "ReplaceMeWithAnyMultiLineCustomField"
    Name                    CurrentlyRunning    HasRunningService   UninstallString
    ----                    ----------------    -----------------   ---------------
    Connectwise Control     Yes                 Yes                 MsiExec /X{examplestring}
    Chrome Remote Desktop   Yes                 Yes                 MsiExec /X{examplestring}

PARAMETER: -ExportJSON "ReplaceMeWithAnyMultiLineCustomField"
    The name of a multiline custom field to export to in JSON format. ex. "RemoteTools"
.EXAMPLE
    -ExportJSON "ReplaceMeWithAnyMultiLineCustomField"
    Name                    CurrentlyRunning    HasRunningService   UninstallString
    ----                    ----------------    -----------------   ---------------
    Connectwise Control     Yes                 Yes                 MsiExec /X{examplestring}
    Chrome Remote Desktop   Yes                 Yes                 MsiExec /X{examplestring}

PARAMETER: -ShowNotFound
    Show the tools the script did not find as well.
.EXAMPLE
    -ShowNotFound
    Name                    CurrentlyRunning    HasRunningService   UninstallString
    ----                    ----------------    -----------------   ---------------
    AeroAdmin               No                  No
    Ammyy Admin             No                  No
    BeyondTrust             No                  No
    Connectwise Control     Yes                 Yes                 MsiExec /X{examplestring}
    Chrome Remote Desktop   Yes                 Yes                 MsiExec /X{examplestring}
    
.OUTPUTS
    None
.NOTES
    General notes: CustomFields must be multiline for export. Regular text is fine for ExclusionsFromCustomField
    Release notes:
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
    [String]$ExcludeTools,
    [Parameter()]
    [String]$ExclusionsFromCustomField,
    [Parameter()]
    [String]$ExportCSV,
    [Parameter()]
    [String]$ExportJSON,
    [Parameter()]
    [Switch]$ShowNotFound
    <#
        ## ParameterName Requirement DefaultValue Type Options Description ##
        ExcludeTools Optional none TEXT Comma seperated list of tools you would not like to look for.
        ExclusionsFromCustomField Optional none TEXT Name of custom field you would like to grab exclusions from.
        ExportCSV Optional none TEXT Name of multi-line custom field you would like to export results to. It will export them in csv format.
        ExportJSON Optional none TEXT Name of multi-line custom field you would like to export results to. It will export them in json format.
        ShowNotFound Optional false CHECKBOX Show results even if it didn't find that specific tool.
    #>
)

begin {
    #DISCLAIMER: This script is provided as a best effort for detecting remote access software installed on an agent, but it is not guaranteed to be 100% accurate. 
    #Some remote access software may not be detected, or false positives may be reported. Use this script at your own risk and verify its results with other methods where possible.

    # Check's the two Uninstall registry keys to see if the app is installed. Needs the name as it would appear in Control Panel.
    function Find-UninstallKey {
        [CmdletBinding()]
        param (
            [Parameter(ValueFromPipeline)]
            [String]$DisplayName,
            [Parameter()]
            [Switch]$UninstallString
        )
        process {
            $UninstallList = New-Object System.Collections.Generic.List[Object]

            $Result = Get-ChildItem HKLM:SoftwareWow6432NodeMicrosoftWindowsCurrentVersionUninstall* | Get-ItemProperty | 
            Where-Object { $_.DisplayName -like "*$DisplayName*" }

            if($Result){ $UninstallList.Add($Result) }

            $Result = Get-ChildItem HKLM:SoftwareMicrosoftWindowsCurrentVersionUninstall* | Get-ItemProperty | 
            Where-Object { $_.DisplayName -like "*$DisplayName*" }

            if($Result){ $UninstallList.Add($Result) }

            # Programs don't always have an uninstall string listed here so to account for that I made this optional.
            if ($UninstallString) {
                # 64 Bit
                $UninstallList | Select-Object -ExpandProperty UninstallString -ErrorAction Ignore
            }
            else {
                $UninstallList
            }
        }
    }

    # This will see if the process is currently active. Some people may want to react sooner to these alerts if its currently running vs not.
    function Find-Process {
        [CmdletBinding()]
        param(
            [Parameter(ValueFromPipeline)]
            [String]$Name
        )
        process {
            Get-Process | Where-Object { $_.ProcessName -like "*$Name*" } | Select-Object -ExpandProperty Name
        }
    }

    # This will search C:ProgramFiles and C:ProgramFiles(x86) for the executable these tools use to run.
    function Find-Executable {
        [CmdletBinding()]
        param(
            [Parameter(ValueFromPipeline)]
            [String]$Path,
            [Parameter()]
            [Switch]$Special
        )
        process {
            if(!$Special){
                if (Test-Path "$env:ProgramFiles$Path") {
                    "$env:ProgramFiles$Path"
                }
        
                if (Test-Path "${Env:ProgramFiles(x86)}$Path") {
                    "${Env:ProgramFiles(x86)}$Path"
                }
    
                if (Test-Path "$env:ProgramData$Path") {
                    "$env:ProgramData$Path"
                }
            }else{
                if(Test-Path $Path){
                    $Path
                }
            }
        }
    }

    # Brought Get-CimInstance outside the function for better performance.

    $ServiceList = Get-CimInstance win32_service
    function Find-Service {
        [CmdletBinding()]
        param(
            [Parameter(ValueFromPipeline)]
            [String]$Name
        )
        process {
            # Get-Service will display an error everytime it has an issue reading a service. Ignoring them as they're not relevant.
            $ServiceList | Where-Object {$_.State -notlike "Disabled" -and $_.State -notlike "Stopped"} | 
            Where-Object {$_.PathName -Like "*$Name.exe*"}
        }
    }

    function Export-CustomField {
        [CmdletBinding()]
        param(
            [Parameter()]
            [String]$Name,
            [Parameter()]
            [ValidateSet("csv", "json")]
            [String]$Format,
            [Parameter()]
            [PSCustomObject]$Object
        )
        if ($Format -eq "csv") {
            $csv = $Object | ConvertTo-Csv -NoTypeInformation | Out-String
            Ninja-Property-Set $Name $csv
        }
        else {
            $json = $Object | ConvertTo-Json | Out-String
            Ninja-Property-Set $Name $json
        }
    }

    # This define's what tools we're looking for and how the script can find them. Some don't actually install anywhere (portable app) others do. 
    # Some change their installation path everytime so not particularly worth it to find it that way.
    # Others store themselves in a super weird directory. Many don't list exactly where there .exe file is stored and suggest you exclude the whole folder from the av.
    $RemoteToolList = @(
        [PSCustomObject]@{Name = "AeroAdmin"; ProcessName = "AeroAdmin" }
        [PSCustomObject]@{Name = "Ammyy Admin"; ProcessName = "AA_v3" }
        [PSCustomObject]@{Name = "AnyDesk"; DisplayName = "AnyDesk"; ProcessName = "AnyDesk"; ExecutablePath = "AnyDeskAnyDesk.exe" }
        [PSCustomObject]@{Name = "BeyondTrust"; DisplayName = "Remote Support Jump Client", "Jumpoint"; ProcessName = "bomgar-jpt" }
        [PSCustomObject]@{Name = "Chrome Remote Desktop"; DisplayName = "Chrome Remote Desktop Host"; ProcessName = "remoting_host"; ExecutablePath = "GoogleChrome Remote Desktop112.0.5615.26remoting_host.exe" }
        [PSCustomObject]@{Name = "Connectwise Control"; DisplayName = "ScreenConnect Client"; ProcessName = "ScreenConnect.ClientService" }
        [PSCustomObject]@{Name = "DWService"; DisplayName = "DWAgent"; ProcessName = "dwagent","dwagsvc"; ExecutablePath = "DWAgentruntimedwagent.exe" }
        [PSCustomObject]@{Name = "GoToMyPC"; DisplayName = "GoToMyPC"; ProcessName = "g2comm", "g2pre", "g2svc", "g2tray"; ExecutablePath = "GoToMyPCg2comm.exe", "GoToMyPCg2pre.exe", "GoToMyPCg2svc.exe", "GoToMyPCg2tray.exe" }
        [PSCustomObject]@{Name = "LiteManager"; DisplayName = "LiteManager Pro - Server"; ProcessName = "ROMServer", "ROMFUSClient"; ExecutablePath = "LiteManager Pro - ServerROMFUSClient.exe", "LiteManager Pro - ServerROMServer.exe" }
        [PSCustomObject]@{Name = "LogMeIn"; DisplayName = "LogMeIn"; ProcessName = "LogMeIn"; ExecutablePath = "LogMeInx64LogMeIn.exe", "LogMeInx64LogMeInSystray.exe" }
        [PSCustomObject]@{Name = "ManageEngine"; DisplayName = "ManageEngine Remote Access Plus - Server", "ManageEngine UEMS - Agent"; ProcessName = "dcagenttrayicon", "UEMS", "dcagentservice"; ExecutablePath = "UEMS_Agentbindcagenttrayicon.exe", "UEMS_CentralServerbinUEMS.exe", "UEMS_Agentbindcagentservice.exe" }
        [PSCustomObject]@{Name = "NoMachine"; DisplayName = "NoMachine"; ProcessName = "nxd", "nxnode.bin", "nxserver.bin", "nxservice64"; ExecutablePath = "NoMachinebinnxd.exe", "NoMachinebinnxnode.bin", "NoMachinebinnxserver.bin", "NoMachinebinnxservice64.exe" }
        [PSCustomObject]@{Name = "Parsec"; DisplayName = "Parsec"; ProcessName = "parsecd", "pservice"; ExecutablePath = "Parsecparsecd.exe", "Parsecpservice.exe" }
        [PSCustomObject]@{Name = "Remote Utilities"; DisplayName = "Remote Utilities - Host"; ProcessName = "rutserv", "rfusclient"; ExecutablePath = "Remote Utilities - Hostrfusclient.exe" }
        [PSCustomObject]@{Name = "RemotePC"; DisplayName = "RemotePC"; ProcessName = "RemotePCHostUI","RPCPerformanceService"; ExecutablePath = "RemotePC HostRemotePCHostUI.exe", "RemotePC HostRemotePCPerformanceRPCPerformanceService.exe" }
        [PSCustomObject]@{Name = "Splashtop"; DisplayName = "Splashtop Streamer"; ProcessName = "SRAgent", "SRAppPB", "SRFeature", "SRManager", "SRService"; ExecutablePath = "SplashtopSplashtop RemoteServerSRService.exe" }
        [PSCustomObject]@{Name = "Supremo"; ProcessName = "Supremo", "SupremoHelper", "SupremoService"; ExecutablePath = "SupremoSupremoService.exe" }
        [PSCustomObject]@{Name = "TeamViewer"; DisplayName = "TeamViewer"; ProcessName = "TeamViewer", "TeamViewer_Service", "tv_w32", "tv_x64"; ExecutablePath = "TeamViewerTeamViewer.exe", "TeamViewerTeamViewer_Service.exe", "TeamViewertv_w32.exe", "TeamViewertv_x64.exe" }
        [PSCustomObject]@{Name = "TightVNC"; DisplayName = "TightVNC"; ProcessName = "tvnserver"; ExecutablePath = "TightVNCtvnserver.exe" }
        [PSCustomObject]@{Name = "UltraVNC"; DisplayName = "UltraVNC"; ProcessName = "winvnc"; ExecutablePath = "uvnc bvbaUltraVNCWinVNC.exe" }
        [PSCustomObject]@{Name = "VNC Connect (RealVNC)"; DisplayName = "VNC Server"; ProcessName = "vncserver"; ExecutablePath = "RealVNCVNC Servervncserver.exe" }
        [PSCustomObject]@{Name = "Zoho Assist"; DisplayName = "Zoho Assist Unattended Agent"; ProcessName = "ZohoURS", "ZohoURSService"; ExecutablePath = "ZohoMeetingUnAttendedZohoMeetingZohoURS.exe", "ZohoMeetingUnAttendedZohoMeetingZohoURSService.exe" }
        [PSCustomObject]@{Name = "Atera"; DisplayName = "AteraAgent"; ProcessName = "AteraAgent"; ExecutablePath = "ATERA NetworksAteraAgentAteraAgent.exe"}
        [PSCustomObject]@{Name = "Automate"; DisplayName = "Connectwise Automate"; ProcessName = "LTService", "LabTechService"; SpecialExecutablePath = "C:WindowsLTSvcLTSvc.exe"}
        [PSCustomObject]@{Name = "Datto RMM"; DisplayName = "Datto RMM"; ProcessName = "AEMAgent"; ExecutablePath = "CentraStageAEMAgentAEMAgent.exe", "CentraStagegui.exe"}
        [PSCustomObject]@{Name = "Kaseya"; DisplayName = "Kaseya Agent"; ProcessName = "AgentMon", "KaseyaRemoteControlHost", "Kasaya.AgentEndpoint"; ExecutablePath = "KaseyaAgentMonAgentMon.exe"}
        [PSCustomObject]@{Name = "N-Able N-Central"; DisplayName = "Windows Agent"; ProcessName = "winagent"; ExecutablePath = "N-able TechnologiesWindows Agentwinagent.exe"}
        [PSCustomObject]@{Name = "N-Able N-Sight"; DisplayName = "Advanced Monitoring Agent"; ProcessName = "winagent"; ExecutablePath = "Advanced Monitoring Agentwinagent.exe", "Advanced Monitoring Agent GPwinagent.exe"}
        [PSCustomObject]@{Name = "Syncro"; DisplayName = "Syncro","Kabuto"; ProcessName = "Syncro.App.Runner", "Kabuto.App.Runner", "Syncro.Service.Runner", "Kabuto.Service.Runner", "SyncroLive.Agent.Runner", "Kabuto.Agent.Runner", "SyncroLive.Agent.Service", "Syncro.Access.Service", "Syncro.Access.App"; ExecutablePath = "RepairTechSyncroSyncro.Service.Runner.exe", "RepairTechSyncroSyncro.App.Runner.exe"}
    )
}
process {

    # Lets see what tools we don't want to alert on.
    $ExcludedTools = New-Object System.Collections.Generic.List[String]

    if ($ExcludeTools) {
        $ExcludedTools.Add(($ExcludeTools.split(',')).Trim())
    }

    # Grabs the info we need from a textbox.
    if ($env:ExcludeTools) {
        $ExcludedTools.Add($env:ExcludeTools.split(','))
    }

    # For this kind of alert it might be worth it to create a whole custom field of ignorables.
    if ($ExclusionsFromCustomField) {
        $ExcludedTools.Add((Ninja-Property-Get $ExclusionsFromCustomField -split(',')).trim())
    }

    if ($env:ExclusionsFromCustomField) {
        $ExcludedTools.Add((Ninja-Property-Get $env:ExclusionsFromCustomField -split(',')).trim())
    }

    if ($ExportCSV -or $Env:ExportCSV) {
        $Format = "csv"

        if ($ExportCSV) {
            $ExportResults = $ExportCSV
        }

        if ($env:ExportCSV) {
            $ExportResults = $env:ExportCSV
        }
    }elseif ($ExportJSON -or $env:ExportJSON) {
        $Format = "json"

        if ($ExportJSON) {
            $ExportResults = $ExportJSON
        }

        if ($env:ExportJSON) {
            $ExportResults = $env:ExportJSON
        }
    }

    # This take's our list and begins searching by the 4 method's in the begin block. 
    $RemoteAccessTools = $RemoteToolList | ForEach-Object {

        $UninstallKey = if ($_.DisplayName) {
            $_.DisplayName | Find-UninstallKey
        }
        
        $UninstallInfo = if ($_.DisplayName) {
            $_.DisplayName | Find-UninstallKey -UninstallString
        }
        
        $RunningStatus = if ($_.ProcessName) {
            $_.ProcessName | Find-Process
        }

        $ServiceStatus = if($_.ProcessName) {
            $_.ProcessName | Find-Service
        }
        
        $InstallPath = if ($_.ExecutablePath) {
            $_.ExecutablePath | Find-Executable
        }elseif($_.SpecialExecutablePath){
            $_.SpecialExecutablePath | Find-Executable -Special
        }

        if ($UninstallKey -or $RunningStatus -or $InstallPath -or $ServiceStatus) {
            $Installed = "Yes"
        }
        else {
            $Installed = "No"
        }

        [PSCustomObject]@{
            Name              = $_.Name
            Installed         = $Installed
            CurrentlyRunning  = if ($RunningStatus) { "Yes" }else { "No" }
            HasRunningService = if ($ServiceStatus) { "Yes" }else { "No" }
            UninstallString   = $UninstallInfo
            ExePath           = $InstallPath
        } | Where-Object { $ExcludedTools -notcontains $_.Name }
    }

    $ActiveRemoteAccessTools = $RemoteAccessTools | Where-Object {$_.Installed -eq "Yes"}

    # If we found anything in the three check's we're gonna indicate it's installed but we may also want to save our results to a custom field.
    # We also may want to output more than "We couldn't find any active remote access tools!" in the event we find nothing.
    if ($ShowNotFound -or $env:ShowNotFound) {

        $RemoteAccessTools | Format-Table -Property Name, Installed, CurrentlyRunning, HasRunningService, UninstallString -AutoSize -Wrap | Out-String | Write-Host

        if($ExportResults){
            Export-CustomField -Name $ExportResults -Format $Format -Object ($RemoteAccessTools | Select-Object Name, Installed, CurrentlyRunning, HasRunningService)
        }

    }else{
        if($ActiveRemoteAccessTools){

            $ActiveRemoteAccessTools | Format-Table -Property Name, CurrentlyRunning, HasRunningService, UninstallString -AutoSize -Wrap | Out-String | Write-Host

            if($ExportResults){
                Export-CustomField -Name $ExportResults -Format $Format -Object ($ActiveRemoteAccessTools | Select-Object Name, CurrentlyRunning, HasRunningService)
            }

        }else{
            Write-Host "We couldn't find any active remote access tools!"
        }
    }

    if($ActiveRemoteAccessTools){
        # We're going to set a failure status code in the event that we find something.
        exit 1
    }
    else {
        exit 0
    }
}