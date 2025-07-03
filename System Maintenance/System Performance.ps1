
[CmdletBinding()]
param (
    [Parameter()]
    $DaysSinceLastReboot,
    [Parameter()]
    [Float]$DurationToPerformTests = 5,
    [Parameter()]
    $NumberOfEvents,
    [Parameter()]
    [String]$WysiwygCustomField,
    [Parameter()]
    [Switch]$SpeedTest = [System.Convert]::ToBoolean($env:performInternetSpeedTest)
)

begin {
    # If script form variables are used, replace command line parameters with their values.
    if ($env:daysSinceLastReboot -and $env:daysSinceLastReboot -notlike "null") { $DaysSinceLastReboot = $env:daysSinceLastReboot }
    if ($env:durationToPerformTests -and $env:durationToPerformTests -notlike "null") { $DurationToPerformTests = $env:durationToPerformTests }
    if ($env:numberOfEvents -and $env:numberOfEvents -notlike "null") { $NumberOfEvents = $env:numberOfEvents }
    if ($env:wysiwygCustomFieldName -and $env:wysiwygCustomFieldName -notlike "null") { $WysiwygCustomField = $env:wysiwygCustomFieldName }

    # Validate the 'Days Since Last Reboot' input.
    if ($DaysSinceLastReboot) {
        try {
            $ErrorActionPreference = "Stop"
            # Attempt to cast the value to a floating-point number.
            $DaysSinceLastReboot = [float]$DaysSinceLastReboot
            $ErrorActionPreference = "Continue"
        }
        catch {
            # If the conversion fails, display an error message and exit the script.
            Write-Host -Object "[Error] The 'Days Since Last Reboot' value of '$DaysSinceLastReboot' is invalid. Please provide a positive whole number or 0."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            exit 1
        }
    }

    # Ensure the value is a whole number (i.e., not a fraction).
    if ($DaysSinceLastReboot -and ($DaysSinceLastReboot % 1) -ne 0) {
        Write-Host -Object "[Error] The 'Days Since Last Reboot' value of '$DaysSinceLastReboot' is invalid. Please provide a positive whole number or 0."
        exit 1
    }

    # Ensure the value is non-negative (greater than or equal to 0).
    if ($DaysSinceLastReboot -and $DaysSinceLastReboot -lt 0) {
        Write-Host -Object "[Error] The 'Days Since Last Reboot' value of '$DaysSinceLastReboot' is invalid. Please provide a positive whole number or 0."
        exit 1
    }

    # Validate the 'Duration To Perform Tests' input.
    if (!$DurationToPerformTests) {
        Write-Host -Object "[Error] Please provide the duration for which you would like to perform the tests using the 'Duration To Perform Tests' box."
        exit 1
    }

    # Ensure the duration is a whole number (i.e., not a fraction).
    if ($DurationToPerformTests -and ($DurationToPerformTests % 1) -ne 0) {
        Write-Host -Object "[Error] The 'Duration To Perform Tests' value of '$DurationToPerformTests' is invalid."
        Write-Host -Object "[Error] Please provide a positive whole number that's greater than 0 and less than or equal to 60."
        exit 1
    }

    # Ensure the duration is between 1 and 60.
    if ($DurationToPerformTests -and ($DurationToPerformTests -lt 1 -or $DurationToPerformTests -gt 60)) {
        Write-Host -Object "[Error] The 'Duration To Perform Tests' value of '$DurationToPerformTests' is invalid."
        Write-Host -Object "[Error] Please provide a positive whole number that's greater than 0 and less than or equal to 60."
        exit 1
    }

    # Validate the 'Number of Events' input.
    if ($NumberOfEvents) {
        try {
            $ErrorActionPreference = "Stop"
            # Attempt to cast the value to a floating-point number.
            $NumberOfEvents = [float]$NumberOfEvents
            $ErrorActionPreference = "Continue"
        }
        catch {
            # If the conversion fails, display an error message and exit the script.
            Write-Host -Object "[Error] The 'Number of Events' value of '$NumberOfEvents' is invalid. Please provide a positive whole number or 0."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            exit 1
        }
    }

    # Ensure the value is a whole number (i.e., not a fraction).
    if ($NumberOfEvents -and ($NumberOfEvents % 1) -ne 0) {
        Write-Host -Object "[Error] The 'Number of Events' value of '$NumberOfEvents' is invalid. Please provide a positive whole number or 0."
        exit 1
    }

    # Ensure the value is non-negative (greater than or equal to 0).
    if ($NumberOfEvents -and $NumberOfEvents -lt 0) {
        Write-Host -Object "[Error] The 'Number of Events' value of '$NumberOfEvents' is invalid. Please provide a positive whole number or 0."
        exit 1
    }

    # If SpeedTest is enabled, ensure the system supports the appropriate TLS versions.
    if ($SpeedTest) {
        # Get the supported TLS versions.
        $SupportedTLSversions = [enum]::GetValues('Net.SecurityProtocolType')

        # Set the security protocol to TLS 1.3 and 1.2 if both are supported.
        if ( ($SupportedTLSversions -contains 'Tls13') -and ($SupportedTLSversions -contains 'Tls12') ) {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol::Tls13 -bor [System.Net.SecurityProtocolType]::Tls12
        }
        elseif ( $SupportedTLSversions -contains 'Tls12' ) {
            # If only TLS 1.2 is supported, set the security protocol to TLS 1.2.
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        }
        else {
            # Warn the user if TLS 1.2 and 1.3 are not supported, as this may cause the download to fail.
            Write-Warning "TLS 1.2 and/or TLS 1.3 are not supported on this system. This may cause downloads to fail!"
            if ($PSVersionTable.PSVersion.Major -lt 3) {
                Write-Warning "PowerShell 2 / .NET 2.0 does not support TLS 1.2."
            }
        }
    }

    function Test-IsServer {
        # Determine the method to retrieve the operating system information based on PowerShell version

        try {
            $OS = if ($PSVersionTable.PSVersion.Major -lt 5) {
                Get-WmiObject -Class Win32_OperatingSystem -ErrorAction Stop
            }
            else {
                Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
            }
        }
        catch {
            Write-Host -Object "[Error] Failed to identity if this device is a workstation or server."
            throw $_
        }
    
        # Check if the ProductType is "3" or "2", which indicates that the system is a server
        if ($OS.ProductType -eq "3" -or $OS.ProductType -eq "2") {
            return $true
        }
    }

    # Check if the script is running on a server.
    try {
        $IsServer = Test-IsServer
    }
    catch {
        Write-Host -Object "[Error] Unable to identify device type."
        Write-Host -Object "[Error] $($_.Exception.Message)`n"
        $ExitCode = 1
    }

    if ($IsServer) {
        # Attempt to check if the RDS role is installed.
        try {
            # Retrieve the RDS role feature and check if it is installed.
            $RDSRole = Get-WindowsFeature -Name RDS-RD-Server | Where-Object { $_.Installed }
        }
        catch {
            # If an error occurs during the check, output an error message and exit the script.
            Write-Host -Object "[Error] Unable to check if the RDS role is installed."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            exit 1
        }

        # If the RDS role is installed, output an error message and exit the script.
        if ($RDSRole) {
            Write-Host -Object "[Error] This script is not compatible with RDS Servers."
            exit 1
        }
    }

    function Test-IsElevated {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object System.Security.Principal.WindowsPrincipal($id)
        $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    # Utility function for downloading files.
    function Invoke-Download {
        param(
            [Parameter()]
            [String]$URL,
            [Parameter()]
            [String]$Path,
            [Parameter()]
            [int]$Attempts = 3,
            [Parameter()]
            [Switch]$SkipSleep
        )

        # Display the URL being used for the download
        Write-Host -Object "URL '$URL' was given."
        Write-Host -Object "Downloading the file..."

        # Determine the supported TLS versions and set the appropriate security protocol
        $SupportedTLSversions = [enum]::GetValues('Net.SecurityProtocolType')
        if ( ($SupportedTLSversions -contains 'Tls13') -and ($SupportedTLSversions -contains 'Tls12') ) {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol::Tls13 -bor [System.Net.SecurityProtocolType]::Tls12
        }
        elseif ( $SupportedTLSversions -contains 'Tls12' ) {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        }
        else {
            # Warn the user if TLS 1.2 and 1.3 are not supported, which may cause the download to fail
            Write-Warning "TLS 1.2 and/or TLS 1.3 are not supported on this system. This download may fail!"
            if ($PSVersionTable.PSVersion.Major -lt 3) {
                Write-Warning "PowerShell 2 / .NET 2.0 doesn't support TLS 1.2."
            }
        }

        # Initialize the attempt counter
        $i = 1
        While ($i -le $Attempts) {
            # If SkipSleep is not set, wait for a random time between 3 and 15 seconds before each attempt
            if (!($SkipSleep)) {
                $SleepTime = Get-Random -Minimum 3 -Maximum 15
                Write-Host "Waiting for $SleepTime seconds."
                Start-Sleep -Seconds $SleepTime
            }
        
            # Provide a visual break between attempts
            if ($i -ne 1) { Write-Host "" }
            Write-Host "Download Attempt $i"

            # Temporarily disable progress reporting to speed up script performance
            $PreviousProgressPreference = $ProgressPreference
            $ProgressPreference = 'SilentlyContinue'
            try {
                if ($PSVersionTable.PSVersion.Major -lt 4) {
                    # For older versions of PowerShell, use WebClient to download the file
                    $WebClient = New-Object System.Net.WebClient
                    $WebClient.DownloadFile($URL, $Path)
                }
                else {
                    # For PowerShell 4.0 and above, use Invoke-WebRequest with specified arguments
                    $WebRequestArgs = @{
                        Uri                = $URL
                        OutFile            = $Path
                        MaximumRedirection = 10
                        UseBasicParsing    = $True
                    }

                    Invoke-WebRequest @WebRequestArgs
                }

                # Verify if the file was successfully downloaded
                $File = Test-Path -Path $Path -ErrorAction SilentlyContinue
            }
            catch {
                # Handle any errors that occur during the download attempt
                Write-Warning "An error has occurred while downloading!"
                Write-Warning $_.Exception.Message

                # If the file partially downloaded, delete it to avoid corruption
                if (Test-Path -Path $Path -ErrorAction SilentlyContinue) {
                    Remove-Item $Path -Force -Confirm:$false -ErrorAction SilentlyContinue
                }

                $File = $False
            }

            # Restore the original progress preference setting
            $ProgressPreference = $PreviousProgressPreference
            # If the file was successfully downloaded, exit the loop
            if ($File) {
                $i = $Attempts
            }
            else {
                # Warn the user if the download attempt failed
                Write-Warning "File failed to download."
                Write-Host ""
            }

            # Increment the attempt counter
            $i++
        }

        # Final check: if the file still doesn't exist, report an error and exit
        if (!(Test-Path $Path)) {
            Write-Host -Object "[Error] Failed to download file."
            Write-Host -Object "Please verify the URL of '$URL'."
            exit 1
        }
        else {
            # If the download succeeded, return the path to the downloaded file
            return $Path
        }
    }

    function Set-NinjaProperty {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory = $True)]
            [String]$Name,
            [Parameter()]
            [String]$Type,
            [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
            $Value,
            [Parameter()]
            [String]$DocumentName
        )
        
        # Measure the number of characters in the provided value
        $Characters = $Value | Out-String | Measure-Object -Character | Select-Object -ExpandProperty Characters
    
        # Throw an error if the value exceeds the character limit of 200,000 characters
        if ($Characters -ge 200000) {
            throw [System.ArgumentOutOfRangeException]::New("Character limit exceeded: the value is greater than or equal to 200,000 characters.")
        }
        
        # Initialize a hashtable for additional documentation parameters
        $DocumentationParams = @{}
    
        # If a document name is provided, add it to the documentation parameters
        if ($DocumentName) { $DocumentationParams["DocumentName"] = $DocumentName }
        
        # Define a list of valid field types
        $ValidFields = "Attachment", "Checkbox", "Date", "Date or Date Time", "Decimal", "Dropdown", "Email", "Integer", "IP Address", "MultiLine", "MultiSelect", "Phone", "Secure", "Text", "Time", "URL", "WYSIWYG"
    
        # Warn the user if the provided type is not valid
        if ($Type -and $ValidFields -notcontains $Type) { Write-Warning "$Type is an invalid type. Please check here for valid types: https://ninjarmm.zendesk.com/hc/en-us/articles/16973443979789-Command-Line-Interface-CLI-Supported-Fields-and-Functionality" }
        
        # Define types that require options to be retrieved
        $NeedsOptions = "Dropdown"
    
        # If the property is being set in a document or field and the type needs options, retrieve them
        if ($DocumentName) {
            if ($NeedsOptions -contains $Type) {
                $NinjaPropertyOptions = Ninja-Property-Docs-Options -AttributeName $Name @DocumentationParams 2>&1
            }
        }
        else {
            if ($NeedsOptions -contains $Type) {
                $NinjaPropertyOptions = Ninja-Property-Options -Name $Name 2>&1
            }
        }
        
        # Throw an error if there was an issue retrieving the property options
        if ($NinjaPropertyOptions.Exception) { throw $NinjaPropertyOptions }
            
        # Process the property value based on its type
        switch ($Type) {
            "Checkbox" {
                # Convert the value to a boolean for Checkbox type
                $NinjaValue = [System.Convert]::ToBoolean($Value)
            }
            "Date or Date Time" {
                # Convert the value to a Unix timestamp for Date or Date Time type
                $Date = (Get-Date $Value).ToUniversalTime()
                $TimeSpan = New-TimeSpan (Get-Date "1970-01-01 00:00:00") $Date
                $NinjaValue = $TimeSpan.TotalSeconds
            }
            "Dropdown" {
                # Convert the dropdown value to its corresponding GUID
                $Options = $NinjaPropertyOptions -replace '=', ',' | ConvertFrom-Csv -Header "GUID", "Name"
                $Selection = $Options | Where-Object { $_.Name -eq $Value } | Select-Object -ExpandProperty GUID
            
                # Throw an error if the value is not present in the dropdown options
                if (!($Selection)) {
                    throw [System.ArgumentOutOfRangeException]::New("Value is not present in dropdown options.")
                }
            
                $NinjaValue = $Selection
            }
            default {
                # For other types, use the value as is
                $NinjaValue = $Value
            }
        }
            
        # Set the property value in the document if a document name is provided
        if ($DocumentName) {
            $CustomField = Ninja-Property-Docs-Set -AttributeName $Name -AttributeValue $NinjaValue @DocumentationParams 2>&1
        }
        else {
            # Otherwise, set the standard property value
            $CustomField = $NinjaValue | Ninja-Property-Set-Piped -Name $Name 2>&1
        }
            
        # Throw an error if setting the property failed
        if ($CustomField.Exception) {
            throw $CustomField
        }
    }

    if (!$ExitCode) {
        $ExitCode = 0
    }

    $StartedDateTime = Get-Date
}
process {
    # Check if the script is being run with elevated (Administrator) privileges.
    # If not, display an error message and exit the script.
    if (!(Test-IsElevated)) {
        Write-Host -Object "[Error] Access Denied. Please run with Administrator privileges."
        exit 1
    }

    # Check if the lock file exists to prevent multiple instances of the script from running.
    # If it exists, read the process ID from the lock file and check if the process is still running.
    if (Test-Path -Path "$env:ProgramData\NinjaRMMAgent\SystemPerformance.lock.txt" -ErrorAction SilentlyContinue) {
        try {
            # Retrieve the process ID from the lock file.
            $OtherScript = Get-Content -Path "$env:ProgramData\NinjaRMMAgent\SystemPerformance.lock.txt" -ErrorAction Stop

            # Check if the process ID exists, indicating the script is already running.
            if (Get-Process -Id $OtherScript -ErrorAction SilentlyContinue) {
                Write-Host -Object "[Error] This script is already running in another process ($OtherScript)."
                exit 1
            }
        }
        catch {
            # If there is an error accessing the lock file, display an error message and exit.
            Write-Host -Object "[Error] Unable to access the lock file at '$env:ProgramData\NinjaRMMAgent\SystemPerformance.lock.txt'."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            exit 1
        }
    }

    # Attempt to write the current process ID to the lock file, preventing multiple instances of the script from running.
    try {
        [System.Diagnostics.Process]::GetCurrentProcess().Id | Out-File -FilePath "$env:ProgramData\NinjaRMMAgent\SystemPerformance.lock.txt" -Force -ErrorAction Stop
    }
    catch {
        # If the lock file cannot be created, display an error message and exit.
        Write-Host -Object "[Error] Failed to create lock file at '$env:ProgramData\NinjaRMMAgent\SystemPerformance.lock.txt'."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        exit 1
    }

    # Get the last reboot time of the system.
    try {
        $LastStartTime = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop | Select-Object -ExpandProperty LastBootUpTime
    }
    catch {
        Write-Host -Object "[Error] Failed to get last start up time."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        $ExitCode = 1
    }

    # If the 'DaysSinceLastReboot' parameter is set, calculate the time difference since the last reboot.
    if ($DaysSinceLastReboot -ge 0) {
        $TimeDifference = New-TimeSpan -Start $LastStartTime -End (Get-Date)

        # If the time since the last reboot exceeds the limit, display an alert to the user.
        if ($TimeDifference.TotalDays -gt $DaysSinceLastReboot) {
            Write-Host -Object "[Alert] This computer was last started on $($LastStartTime.ToShortDateString()) at $($LastStartTime.ToShortTimeString()) which was $([math]::Round($TimeDifference.TotalDays,2)) days ago."
            $ExceededLastStartupLimit = $True
        }
    }

    # Initialize an empty list to store event logs.
    $EventLogs = New-Object System.Collections.Generic.List[object]

    # Define XML queries for Application, Security, Setup, and System event logs that have error level events (Level=2).
    [xml]$ApplicationXML = @"
<QueryList>
  <Query Id="0" Path="Application">
    <Select Path="Application">*[System[(Level=2)]]</Select>
  </Query>
</QueryList>
"@

    [xml]$SecurityLogs = @"
<QueryList>
  <Query Id="0" Path="Application">
    <Select Path="Security">*[System[(Level=2)]]</Select>
  </Query>
</QueryList>
"@

    [xml]$SetupLogs = @"
<QueryList>
  <Query Id="0" Path="Application">
    <Select Path="Setup">*[System[(Level=2)]]</Select>
  </Query>
</QueryList>
"@

    [xml]$SystemLogs = @"
<QueryList>
  <Query Id="0" Path="Application">
    <Select Path="System">*[System[(Level=2)]]</Select>
  </Query>
</QueryList>
"@

    # If the 'NumberOfEvents' parameter is set, collect the specified number of error logs from each log category.
    if ($NumberOfEvents) {
        Write-Host -Object "`nCollecting event logs."

        # Collect logs from each category and store them in the EventLogs list.
        Get-WinEvent -MaxEvents $NumberOfEvents -FilterXml $ApplicationXML -ErrorAction SilentlyContinue -ErrorVariable EventLogErrors | ForEach-Object { $EventLogs.Add($_) }
        Get-WinEvent -MaxEvents $NumberOfEvents -FilterXml $SecurityLogs -ErrorAction SilentlyContinue -ErrorVariable EventLogErrors | ForEach-Object { $EventLogs.Add($_) }
        Get-WinEvent -MaxEvents $NumberOfEvents -FilterXml $SetupLogs -ErrorAction SilentlyContinue -ErrorVariable EventLogErrors | ForEach-Object { $EventLogs.Add($_) }
        Get-WinEvent -MaxEvents $NumberOfEvents -FilterXml $SystemLogs -ErrorAction SilentlyContinue -ErrorVariable EventLogErrors | ForEach-Object { $EventLogs.Add($_) }

        # If any errors occurred during log collection, display warnings with the error details.
        if ($EventLogErrors) {
            $EventLogErrors | ForEach-Object {
                Write-Warning -Message "$($_.Exception.Message)"
            }
        }

        # If no error logs were found, display a warning message.
        if ($EventLogs.Count -eq 0) {
            Write-Warning -Message "No error events were found in the event log."
        }
        else {
            $EventLogs = $EventLogs | Select-Object LogName, ProviderName, Id, TimeCreated, Message | Sort-Object -Property TimeCreated -Descending
        }
    }

    # Notify the user that performance metrics are being collected for the specified duration.
    Write-Host -Object "Collecting performance metrics for $DurationToPerformTests minutes."

    # Collect performance metrics (CPU, memory, disk, and network usage) at a 60-second interval for the specified duration.
    $PerformanceMetrics = Get-Counter -MaxSamples $DurationToPerformTests -SampleInterval 60 -Counter "\Process(*)\% User Time", "\Process(*)\Working Set - Private", "\Process(*)\IO Data Bytes/sec", "\Processor(*)\% Processor Time", "\Memory\% Committed Bytes In Use", "\PhysicalDisk(*)\Disk Transfers/sec", "\Network Interface(*)\Bytes Total/sec" -ErrorAction SilentlyContinue -ErrorVariable PerformanceMetricErrors

    # Extract performance metrics for CPU, memory, I/O, disk, and network usage from the collected data.
    $OverallProcessorUsage = $PerformanceMetrics | Select-Object -ExpandProperty CounterSamples | Where-Object { $_.Path -match '% Processor Time$' }
    $OverallMemoryUsage = $PerformanceMetrics | Select-Object -ExpandProperty CounterSamples | Where-Object { $_.Path -match '% Committed Bytes In Use$' }
    $ProcessorUsage = $PerformanceMetrics | Select-Object -ExpandProperty CounterSamples | Where-Object { $_.Path -match '% user time$' }
    $MemoryUsage = $PerformanceMetrics | Select-Object -ExpandProperty CounterSamples | Where-Object { $_.Path -match 'Working Set - Private$' }
    $IOUsage = $PerformanceMetrics | Select-Object -ExpandProperty CounterSamples | Where-Object { $_.Path -match 'IO Data Bytes/sec$' }
    $DiskUsage = $PerformanceMetrics | Select-Object -ExpandProperty CounterSamples | Where-Object { $_.Path -match 'Disk Transfers/sec$' }
    $NetworkUsage = $PerformanceMetrics | Select-Object -ExpandProperty CounterSamples | Where-Object { $_.Path -match 'Bytes Total/sec$' }

    # If there were errors during the collection of performance metrics, display a warning message for each error.
    if ($PerformanceMetricErrors) {
        $PerformanceMetricErrors | ForEach-Object {
            Write-Warning -Message "$($_.Exception.Message)"
        }
    }

    # Ensure that performance metrics for CPU, memory, I/O, disk, and network usage were successfully retrieved.
    # If any of the metrics are missing, display an error message and exit the script.
    if (!$OverallProcessorUsage -or !$OverallMemoryUsage -or !$ProcessorUsage -or !$MemoryUsage -or !$IOUsage -or !$DiskUsage -or !$NetworkUsage) {
        Write-Host -Object "[Error] Failed to retrieve performance metrics."
        exit 1
    }

    # Retrieve CPU information such as name and clock speed (in GHz).
    try {
        $CPU = "$(Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -ExpandProperty Name) $((Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -ExpandProperty MaxClockSpeed)/1000) GHz"

        # Retrieve the total amount of installed physical memory (RAM) in bytes and convert it to GB.
        $TotalMemoryBytes = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction Stop | Measure-Object -Property Capacity -Sum | Select-Object -ExpandProperty Sum
        $TotalMemoryGB = "$($TotalMemoryBytes/1GB) GB"
    }
    catch {
        Write-Host -Object "[Error] Unable to get CPU or Memory details."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        $ExitCode = 1
    }

    # Display the CPU information.
    Write-Host -Object "`n### $CPU ###"

    # Filter and sort the relevant CPU performance metrics for the "_total" instance (overall system usage).
    $RelevantMetrics = $OverallProcessorUsage | Where-Object { $_.InstanceName -eq "_total" } | Sort-Object CookedValue

    # Calculate average, minimum, and maximum CPU usage.
    $CPUPerformance = [PSCustomObject]@{
        Avg = [math]::Round((($RelevantMetrics | Measure-Object -Property CookedValue -Sum | Select-Object -ExpandProperty Sum) / $DurationToPerformTests), 2)
        Min = [math]::Round(($RelevantMetrics | Select-Object -ExpandProperty CookedValue -First 1), 2)
        Max = [math]::Round(($RelevantMetrics | Select-Object -ExpandProperty CookedValue -Last 1), 2)
    }

    # Format the CPU performance metrics for display.
    $FormattedCPUPerformance = [PSCustomObject]@{
        "CPU Average %" = "$($CPUPerformance.Avg)%"
        "CPU Minimum %" = "$($CPUPerformance.Min)%"
        "CPU Maximum %" = "$($CPUPerformance.Max)%"
    }

    # Display the formatted CPU performance metrics.
    ($FormattedCPUPerformance | Format-Table -AutoSize | Out-String).Trim() | Write-Host

    # Display memory usage header.
    Write-Host -Object "`n### Memory Usage ###"
    Write-Host -Object "Total Memory Installed: $TotalMemoryGB"

    # Filter and sort the relevant memory usage metrics.
    $RelevantMetrics = $OverallMemoryUsage | Sort-Object CookedValue

    # Calculate average, minimum, and maximum memory usage.
    $MemoryPerformance = [PSCustomObject]@{
        Avg = [math]::Round((($RelevantMetrics | Measure-Object -Property CookedValue -Sum | Select-Object -ExpandProperty Sum) / $DurationToPerformTests), 2)
        Min = [math]::Round(($RelevantMetrics | Select-Object -ExpandProperty CookedValue -First 1), 2)
        Max = [math]::Round(($RelevantMetrics | Select-Object -ExpandProperty CookedValue -Last 1), 2)
    }

    # Format the memory performance metrics for display.
    $OverallMemoryMetrics = [PSCustomObject]@{
        "RAM Average %" = "$($MemoryPerformance.Avg)%"
        "RAM Minimum %" = "$($MemoryPerformance.Min)%"
        "RAM Maximum %" = "$($MemoryPerformance.Max)%"
    }

    # Display the formatted memory performance metrics.
    ($OverallMemoryMetrics | Format-Table -AutoSize | Out-String).Trim() | Write-Host

    # Display the header for the top 5 CPU processes.
    Write-Host "`n### Top 5 CPU Processes ###"

    # Get a unique list of all process names excluding the "_total" instance.
    $AllProcessNames = $ProcessorUsage | Where-Object { $_.InstanceName -ne "_total" } | Sort-Object InstanceName -Unique | Select-Object -ExpandProperty InstanceName

    # Initialize an empty list to store process metrics.
    $Processes = New-Object -TypeName System.Collections.Generic.List[object]

    # Loop through each process name to calculate the CPU usage (min, max, avg) for each process.
    foreach ($ProcessName in $AllProcessNames) {
        $RelevantMetrics = $ProcessorUsage | Where-Object { $_.InstanceName -eq $ProcessName }

        # Group metrics by timestamp and calculate the total CPU usage for each timestamp.
        $GroupedMetrics = $RelevantMetrics | Group-Object Timestamp | Select-Object @{Name = "InstanceName"; Expression = { $ProcessName } }, @{Name = "CookedValue"; Expression = { $_.Group | Measure-Object -Property CookedValue -Sum | Select-Object -ExpandProperty Sum } } | Sort-Object CookedValue
        
        # Add the CPU usage metrics (min, max, avg) for each process to the list.
        $Processes.Add(
            [PSCustomObject]@{
                "InstanceName" = $ProcessName
                "Min"          = $GroupedMetrics | Select-Object -ExpandProperty CookedValue -First 1
                "Max"          = $GroupedMetrics | Select-Object -ExpandProperty CookedValue -Last 1
                "Avg"          = ($GroupedMetrics | Measure-Object -Property CookedValue -Sum | Select-Object -ExpandProperty Sum) / $DurationToPerformTests
            }
        )
    }

    # Sort the processes by average CPU usage in descending order and select the top 5.
    $Top5CPUProcesses = $Processes | Sort-Object "Avg" -Descending | Select-Object -First 5

    # Format the top 5 CPU processes for display.
    $FormattedProcesses = $Top5CPUProcesses | ForEach-Object {
        [PSCustomObject]@{
            "Process Name"       = $_.InstanceName
            "Average CPU % Used" = "$([math]::Round($_.Avg, 2))%"
            "Minimum CPU % Used" = "$([math]::Round($_.Min, 2))%"
            "Maximum CPU % Used" = "$([math]::Round($_.Max, 2))%"
        }
    } 

    # Display the formatted CPU process usage metrics.
    ($FormattedProcesses | Format-Table -AutoSize | Out-String).Trim() | Write-Host

    # Display the header for the top 5 RAM processes.
    Write-Host -Object "`n### Top 5 RAM Processes ###"

    # Get a unique list of process names that are not "_total" or "memory compression".
    $AllMemoryProcessNames = $MemoryUsage | Where-Object { $_.InstanceName -ne "_total" -and $_.InstanceName -ne "memory compression" } | Sort-Object InstanceName -Unique | Select-Object -ExpandProperty InstanceName

    # Initialize an empty list to store memory process metrics.
    $MemoryProcesses = New-Object -TypeName System.Collections.Generic.List[object]

    # Loop through each process to calculate the memory usage (min, max, avg) for each process.
    foreach ($ProcessName in $AllMemoryProcessNames) {
        $RelevantMetrics = $MemoryUsage | Where-Object { $_.InstanceName -eq $ProcessName }

        # Group metrics by timestamp and calculate the total memory usage for each timestamp.
        $GroupedMetrics = $RelevantMetrics | Group-Object Timestamp | Select-Object @{Name = "InstanceName"; Expression = { $ProcessName } }, @{Name = "CookedValue"; Expression = { $_.Group | Measure-Object -Property CookedValue -Sum | Select-Object -ExpandProperty Sum } } | Sort-Object CookedValue
        
        # Add the memory usage metrics (min, max, avg) for each process to the list.
        $MemoryProcesses.Add(
            [PSCustomObject]@{
                "InstanceName" = $ProcessName
                "Min"          = $GroupedMetrics | Select-Object -ExpandProperty CookedValue -First 1
                "Max"          = $GroupedMetrics | Select-Object -ExpandProperty CookedValue -Last 1
                "Avg"          = ($GroupedMetrics | Measure-Object -Property CookedValue -Sum | Select-Object -ExpandProperty Sum) / $DurationToPerformTests
            }
        )
    }

    # Sort the processes by average memory usage in descending order and select the top 5.
    $Top5RAMProcesses = $MemoryProcesses | Sort-Object "Avg" -Descending | Select-Object -First 5 | ForEach-Object {
        if (!$TotalMemoryBytes) {
            return
        }

        [PSCustomObject]@{
            "InstanceName" = $_.InstanceName
            "Min"          = $_.Min / $TotalMemoryBytes * 100
            "Max"          = $_.Max / $TotalMemoryBytes * 100
            "Avg"          = $_.Avg / $TotalMemoryBytes * 100
        }
    }

    # Format the top 5 RAM processes for display.
    $FormattedMemoryProcesses = $Top5RAMProcesses | ForEach-Object {
        if (!$TotalMemoryBytes) {
            return
        }

        [PSCustomObject]@{
            "Process Name"       = $_.InstanceName
            "Average RAM % Used" = "$([math]::Round($_.Avg, 2))%"
            "Minimum RAM % Used" = "$([math]::Round($_.Min, 2))%"
            "Maximum RAM % Used" = "$([math]::Round($_.Max, 2))%"
        }
    }
    
    # Display the formatted memory process usage metrics.
    ($FormattedMemoryProcesses | Format-Table -AutoSize | Out-String).Trim() | Write-Host

    # Display the header for network usage.
    Write-Host -Object "`n### Network Usage ###"

    # Get a unique list of network interfaces and initialize an empty list for storing network metrics.
    $NetworkInterfaces = $NetworkUsage | Sort-Object InstanceName -Unique | Select-Object -ExpandProperty InstanceName
    $NetworkInterfaceUsage = New-Object -TypeName System.Collections.Generic.List[object]

    # Loop through each network interface to calculate the network usage (min, max, avg) for each interface.
    foreach ($NetworkInterface in $NetworkInterfaces) {
        $RelevantMetrics = $NetworkUsage | Where-Object { $_.InstanceName -eq $NetworkInterface } | Sort-Object CookedValue

        try {
            # Correct the network interface name if necessary to match the system's adapter description.
            if (!(Get-NetAdapter -ErrorAction Stop | Where-Object { $_.InterfaceDescription -eq $NetworkInterface })) {
                $NetworkInterface = $NetworkInterface -replace '\[', '(' -replace '\]', ')'
            }

            # Retrieve the network adapter details and determine if it's wired, Wi-Fi, or another type.
            $NetAdapter = Get-NetAdapter -ErrorAction Stop | Where-Object { $_.InterfaceDescription -eq $NetworkInterface } | Select-Object -First 1
            switch -Wildcard ($NetAdapter.MediaType) {
                "802.3" { $AdapterType = "Wired" }
                "*802.11" { $AdapterType = "Wi-Fi" }
                default { $AdapterType = "Other" }
            }
        }
        catch {
            Write-Host -Object "[Error] Failed to get details on the network interface '$NetworkInterface'."
            Write-Host -Object "[Error] $($_.Exception.Message)`n"
            $ExitCode = 1
            continue
        }

        # Add the network adapter usage metrics to the list.
        $NetworkInterfaceUsage.Add(
            [PSCustomObject]@{
                "NetworkAdapter" = $NetworkInterface
                "MacAddress"     = $NetAdapter.MacAddress
                "Type"           = $AdapterType
                "Min"            = $RelevantMetrics | Select-Object -ExpandProperty CookedValue -First 1
                "Max"            = $RelevantMetrics | Select-Object -ExpandProperty CookedValue -Last 1
                "Avg"            = ($RelevantMetrics | Measure-Object -Property CookedValue -Sum | Select-Object -ExpandProperty Sum) / $DurationToPerformTests
            }
        )
    }

    # Format the network usage metrics for display.
    $FormattedNetworkUsage = $NetworkInterfaceUsage | Sort-Object "Avg" -Descending | ForEach-Object {
        [PSCustomObject]@{
            "NetworkAdapter"          = $_.NetworkAdapter
            "MacAddress"              = $_.MacAddress
            "Type"                    = $_.Type
            "Average Sent & Received" = "$([math]::Round(($_.Avg / 1MB * 8), 2)) Mbps"
            "Minimum Sent & Received" = "$([math]::Round(($_.Min / 1MB * 8), 2)) Mbps"
            "Maximum Sent & Received" = "$([math]::Round(($_.Max / 1MB * 8), 2)) Mbps"
        }
    }
    
    # Display the formatted network usage metrics.
    ($FormattedNetworkUsage | Format-List | Out-String).Trim() | Write-Host

    # Display the header for disk usage.
    Write-Host -Object "`n### Disk Usage ###"

    # Get a unique list of relevant disks and initialize an empty list for storing disk metrics.
    $RelevantDisks = $DiskUsage | Where-Object { $_.InstanceName -ne "_total" } | Sort-Object InstanceName -Unique | Select-Object -ExpandProperty InstanceName
    $DiskMetrics = New-Object -TypeName System.Collections.Generic.List[object]

    try {
        $AllDiskNumbers = Get-Partition -ErrorAction Stop | Select-Object -ExpandProperty DiskNumber -Unique
    }
    catch {
        Write-Host -Object "[Error] Unable to retrieve disk numbers."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        $ExitCode = 1
    }

    # Loop through each disk to calculate the disk usage (min, max, avg) for each disk.
    foreach ($RelevantDisk in $RelevantDisks) {
        $RelevantMetrics = $DiskUsage | Where-Object { $_.InstanceName -eq $RelevantDisk } | Sort-Object CookedValue

        # Parse the disk number and drive letter from the instance name.
        $DiskNumber = $RelevantDisk -split '\s' | Where-Object { $_ -match "^[0-9]$" }
        $DriveLetters = ($RelevantDisk -split '\s' | Where-Object { $_ -match "^[A-z]:$" }) -replace ':'

        # Retrieve the physical disk based on the provided DiskNumber.
        $PhysicalDisk = Get-PhysicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DeviceId -eq $DiskNumber }

        # Check if the disk number is part of the list of all disk numbers.
        if ($AllDiskNumbers -and $AllDiskNumbers -notcontains $DiskNumber) {

            # If the physical disk has a FriendlyName (meaning it was found), warn that no partitions were found on this disk.
            if ($PhysicalDisk.FriendlyName) {
                Write-Warning -Message "No partitions found on disk '$($PhysicalDisk.FriendlyName)'."
            }
            else {
                # If the physical disk has no FriendlyName, display a warning message using the DiskNumber.
                Write-Warning -Message "No partitions found on disk '$DiskNumber'."
            }
     
            Write-Host -Object ""

            # Continue to the next iteration in the loop, skipping the remaining code for this disk number.
            continue
        }

        # Attempt to retrieve the partitions for the specified disk number.
        try {
            $Partitions = Get-Partition -DiskNumber $DiskNumber -ErrorAction Stop
        }
        catch {
            # If an error occurs while getting the partitions, display an error message.
            Write-Host -Object "[Error] Accessing Partitions on disk '$DiskNumber'"

            # Display the exception message from the caught error.
            Write-Host -Object "[Error] $($_.Exception.Message)`n"

            # Set the exit code to indicate an error occurred.
            $ExitCode = 1

            # Continue to the next iteration in the loop, skipping further actions for this disk number.
            continue
        }

        # Retrieve partition information and add the disk usage metrics to the list.
        foreach ($DriveLetter in $DriveLetters) {
            $Partitions | Where-Object { $_.DriveLetter -eq $DriveLetter } | ForEach-Object {
                try {
                    $FreeSpace = Get-Volume -ErrorAction Stop | Where-Object { $_.DriveLetter -eq $DriveLetter } | Select-Object -ExpandProperty SizeRemaining
                    $TotalSize = Get-Volume -ErrorAction Stop | Where-Object { $_.DriveLetter -eq $DriveLetter } | Select-Object -ExpandProperty Size
                }
                catch {
                    Write-Host -Object "[Error] Unable to determine the total size or free space of drive '$DriveLetter'."
                    Write-Host -Object "[Error] $($_.Exception.Message)`n"
                    $ExitCode = 1
                    continue
                }

                $FreeSpaceGB = [math]::Round(($FreeSpace / 1GB), 2)
                $FreeSpacePercent = [math]::Round(($FreeSpace / $TotalSize * 100), 2)
                $TotalSpaceGB = [math]::Round(($TotalSize / 1GB), 2)

                # Add the disk metrics to the list.
                $DiskMetrics.Add(
                    [PSCustomObject]@{
                        "DriveLetter"      = $_.DriveLetter
                        "FreeSpaceGB"      = $FreeSpaceGB
                        "FreeSpacePercent" = $FreeSpacePercent
                        "TotalSpace"       = "$TotalSpaceGB GB"
                        "PhysicalDisk"     = $PhysicalDisk | Select-Object -ExpandProperty FriendlyName
                        "MediaType"        = $PhysicalDisk | Select-Object -ExpandProperty MediaType
                        "Min"              = $RelevantMetrics | Select-Object -ExpandProperty CookedValue -First 1
                        "Max"              = $RelevantMetrics | Select-Object -ExpandProperty CookedValue -Last 1
                        "Avg"              = ($RelevantMetrics | Measure-Object -Property CookedValue -Sum | Select-Object -ExpandProperty Sum) / $DurationToPerformTests
                    }
                )
            }
        }
    }

    # Add the disk metrics to the list.
    $FormattedDiskMetrics = $DiskMetrics | Sort-Object "Avg" -Descending | ForEach-Object {
        [PSCustomObject]@{
            "DriveLetter"  = $_.DriveLetter
            "FreeSpace"    = "$($_.FreeSpaceGB) GB ($($_.FreeSpacePercent)%)"
            "TotalSpace"   = $_.TotalSpace
            "PhysicalDisk" = $_.PhysicalDisk
            "MediaType"    = $_.MediaType
            "Average IOPS" = "$([math]::Round(($_.Avg), 2)) IOPS"
            "Minimum IOPS" = "$([math]::Round(($_.Min), 2)) IOPS"
            "Maximum IOPS" = "$([math]::Round(($_.Max), 2)) IOPS"
        }
    }
    
    # Display the formatted disk usage metrics.
    ($FormattedDiskMetrics | Format-Table | Out-String).Trim() | Write-Host

    # Display the header for top 5 I/O processes (network and disk combined).
    Write-Host -Object "`n### Top 5 IO Processes (Network & Disk Combined) ###"

    # Get a unique list of I/O process names excluding the "_total" instance.
    $AllIOProcessNames = $IOUsage | Where-Object { $_.InstanceName -ne "_total" } | Sort-Object InstanceName -Unique | Select-Object -ExpandProperty InstanceName
    $IOProcesses = New-Object -TypeName System.Collections.Generic.List[object]

    # Loop through each process to calculate the I/O usage (min, max, avg) for each process.
    foreach ($ProcessName in $AllIOProcessNames) {
        $RelevantMetrics = $IOUsage | Where-Object { $_.InstanceName -eq $ProcessName }

        # Group metrics by timestamp and calculate the total I/O usage for each timestamp.
        $GroupedMetrics = $RelevantMetrics | Group-Object Timestamp | Select-Object @{Name = "InstanceName"; Expression = { $ProcessName } }, @{Name = "CookedValue"; Expression = { $_.Group | Measure-Object -Property CookedValue -Sum | Select-Object -ExpandProperty Sum } } | Sort-Object CookedValue
        
        # Add the I/O usage metrics to the list.
        $IOProcesses.Add(
            [PSCustomObject]@{
                "InstanceName" = $ProcessName
                "Min"          = $GroupedMetrics | Select-Object -ExpandProperty CookedValue -First 1
                "Max"          = $GroupedMetrics | Select-Object -ExpandProperty CookedValue -Last 1
                "Avg"          = ($GroupedMetrics | Measure-Object -Property CookedValue -Sum | Select-Object -ExpandProperty Sum) / $DurationToPerformTests
            }
        )
    }

    # Sort the I/O processes by average I/O usage and select the top 5.
    $Top5IOProcesses = $IOProcesses | Sort-Object "Avg" -Descending | Select-Object -First 5

    # Format the top 5 I/O processes for display.
    $FormattedIOProcesses = $Top5IOProcesses | ForEach-Object {
        [PSCustomObject]@{
            "Process Name"    = $_.InstanceName
            "Average IO Used" = "$([math]::Round(($_.Avg / 1MB * 8), 4)) Mbps"
            "Minimum IO Used" = "$([math]::Round(($_.Min / 1MB * 8), 4)) Mbps"
            "Maximum IO Used" = "$([math]::Round(($_.Max / 1MB * 8), 4)) Mbps"
        }
    } 
    
    # Display the formatted I/O process usage metrics.
    ($FormattedIOProcesses | Format-Table -AutoSize | Out-String).Trim() | Write-Host

    # Inform the user that WinSAT assessments are running.
    Write-Host -Object "`nRetrieving WinSAT assessment data."
    Write-Host -Object "More info: https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-8.1-and-8/hh825488(v=win.10)"

    # Retrieve the WinSAT assessment scores.
    try {
        $WinSatScores = Get-CimInstance -ClassName Win32_WinSAT -ErrorAction Stop
    }
    catch {
        Write-Host -Object "[Error] Unable to retrieve WinSat assessment results."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        $ExitCode = 1
    }

    # Handle the different possible states of the WinSAT assessment.
    switch ($WinSatScores.WinSATAssessmentState) {
        0 { Write-Host -Object "[Error] WinSAT assessment data is not available on this computer" ; $ExitCode = 1 }
        1 { Write-Host -Object "Successfully retrieved assessment data." }
        2 { Write-Warning -Message "The WinSAT assessment data does not match the current computer configuration." }
        3 { Write-Host -Object "[Error] WinSAT assessment data is not available on this computer" ; $ExitCode = 1 }
        4 { Write-Host -Object "[Error] The WinSAT assessment data is not valid!" ; $ExitCode = 1 }
        default {
            Write-Host -Object "[Error] WinSAT assessment data is not available on this computer" ; $ExitCode = 1
        }
    }    

    # If the WinSAT assessment state is valid, display the assessment scores.
    $ValidAssessmentStates = "1", "2"
    if ($ValidAssessmentStates -contains $WinSatScores.WinSATAssessmentState) {
        Write-Host -Object "`n### WinSAT Scores ###"
        ($WinSatScores | Format-Table -Property CPUScore, D3DScore, DiskScore, GraphicsScore, MemoryScore | Out-String).Trim() | Write-Host
    }

    if ($SpeedTest) {
        # Get the latest version of the Speedtest CLI
        $CLIdownloadPage = "https://www.speedtest.net/apps/cli"
        Write-Host -Object "`nAttempting to find the latest Speedtest CLI portable app download link using '$CLIdownloadPage'."

        # Temporarily disable progress reporting to speed up script performance
        $PreviousProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        
        # Initialize the attempt counter for downloading the Speedtest CLI
        $i = 1
        $Attempts = 3
        While ($i -le $Attempts) {
            # Log the current attempt number
            Write-Host -Object "Attempt $i"

            # Attempt to download the Speedtest CLI download page
            try {
                $WebRequestArgs = @{
                    Uri                = $CLIdownloadPage
                    MaximumRedirection = 10
                    UseBasicParsing    = $True
                }

                $Cli = Invoke-WebRequest @WebRequestArgs
            }
            catch {
                Write-Warning "Failed to query https://www.speedtest.net/apps/cli for Speedtest cli portable app."
                Write-Warning $_.Exception.Message

                $Cli = $Null
            }
        
            if ($Cli) {
                # If successful, break out of the loop by setting the counter to the maximum
                $i = $Attempts
            }
            else {
                # Generate a random sleep time between 3 and 15 seconds for future attempts
                $SleepTime = Get-Random -Minimum 3 -Maximum 15
                Write-Host -Object "Waiting $SleepTime seconds before next attempt."

                # Sleep for the generated amount of time
                Start-Sleep -Seconds $SleepTime
            }

            # Increment the attempt counter
            $i++
        }

        # Restore the original progress preference setting
        $ProgressPreference = $PreviousProgressPreference
    
        # Get the download link for the Speedtest CLI
        $Url = $Cli.Links | Where-Object { $_.href -like "*win64*" } | Select-Object -ExpandProperty href
        if (!$Url) {
            Write-Host -Object "[Error] Unable to find the latest URL for Speedtest CLI."
            exit 1
        }

        # Log the found download link
        Write-Host -Object "Download link found: $Url."

        # Log the download attempt
        Write-Host -Object "Attempting to download the Speedtest CLI portable app."
    
        # Download the ZIP file to a temporary location
        $SpeedTestZip = Invoke-Download -URL $Url -Path "$env:TEMP\speedtest.zip"

        try {
            # Set error action preference to stop to handle any errors immediately
            $ErrorActionPreference = "Stop"

            # If available, use PowerShell's Expand-Archive cmdlet to unzip the speedtest.zip file
            if ($(Get-Command -Name "Expand-Archive" -ErrorAction SilentlyContinue).Count) {
                Expand-Archive -Path $SpeedTestZip -DestinationPath "$env:TEMP\SpeedTest" -Force
            }
            else {
                # Unzip the Speedtest cli zip using .NET methods
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                if ((Test-Path -Path "$env:TEMP\SpeedTest" -ErrorAction SilentlyContinue)) {
                    Remove-Item -Path "$env:TEMP\SpeedTest" -Recurse -Force -Confirm:$false
                }
                [System.IO.Compression.ZipFile]::ExtractToDirectory($SpeedTestZip, "$env:TEMP\SpeedTest")
            }

            $ErrorActionPreference = "Continue"
        }
        catch {
            # Log an error if unzipping fails
            Write-Host -Object "[Error] Failed to unzip SpeedTest.zip"
            Write-Host -Object "[Error] $($_.Exception.Message)"
            exit 1
        }

        # Check if the Speedtest executable is present in the extracted files
        if (!(Test-Path -Path "$env:TEMP\SpeedTest\speedtest.exe" -ErrorAction SilentlyContinue)) {
            Write-Host -Object "[Error] The file speedtest.exe was not found in $env:TEMP\SpeedTest."
            exit 1
        }

        # Accept the privacy policy and license agreement, output the results in JSON format and include server details in the output.
        $SpeedTestArguments = @(
            "--accept-license"
            "--accept-gdpr"
            "--format=json"
            "-v"
            "--selection-details"
        )

        # Check if the favorite server file exists and no specific server ID is provided
        if ((Test-Path -Path "$env:ProgramData\NinjaRMMAgent\speedtest-serverid.txt" -ErrorAction SilentlyContinue)) {
            try {
                $FavoriteServer = Get-Content -Path "$env:ProgramData\NinjaRMMAgent\speedtest-serverid.txt" | Out-String | ConvertFrom-Json
                if (!$FavoriteServer.Id -or !$FavoriteServer.name) {
                    throw "JSON is malformed."
                }
            }
            catch {
                Write-Host -Object "[Error] Favorite Speedtest server file is invalid, removing file."
                Remove-Item -Path "$env:ProgramData\NinjaRMMAgent\speedtest-serverid.txt" -Force -ErrorAction SilentlyContinue
                $FavoriteServer = $Null
                $ExitCode = 1
            }
        }

        # If a favorite server was found, set it as the server to test against
        if ($FavoriteServer) {
            $SpeedTestArguments = @(
                "-s $($FavoriteServer.id)"
                "--accept-license"
                "--accept-gdpr"
                "--format=json"
                "-v"
                "--selection-details"
            )
        }

        # Create a unique file path for the stdout and stderr log
        $stdoutlog = "$env:TEMP\SpeedTest\stdout-$(Get-Random).log"
        $stderrlog = "$env:TEMP\SpeedTest\stderr-$(Get-Random).log"

        # Prepare the arguments for starting the Speedtest process
        $SpeedTestProcessArguments = @{
            FilePath               = "$env:TEMP\SpeedTest\speedtest.exe"
            RedirectStandardOutput = $stdoutlog
            RedirectStandardError  = $stderrlog
            ArgumentList           = $SpeedTestArguments
            Wait                   = $True
            PassThru               = $True
            NoNewWindow            = $True
        }

        # Attempt to start the Speedtest process
        try {
            if (!$FavoriteServer) {
                Write-Host -Object "`nStarting the Speedtest."
            }
            else {
                Write-Host -Object "`nRunning Speedtest using the favorite server '$($FavoriteServer.name)'."
            }

            $SpeedTestProcess = Start-Process @SpeedTestProcessArguments -ErrorAction Stop
        }
        catch {
            Write-Host -Object "[Error] Failed to start $env:TEMP\SpeedTest\speedtest.exe"
            Write-Host -Object "[Error] $($_.Exception.Message)"
            exit 1
        }
    
        # Log the exit code of the Speedtest process
        Write-Host -Object "Exit Code: $($SpeedTestProcess.ExitCode)"
        if ($SpeedTestProcess.ExitCode -ne 0) {
            Write-Host -Object "[Error] Exit Code does not indicate success."
            $ExitCode = 1
        }

        # If the stderr log exists, process the output
        if (Test-Path -Path $stderrlog -ErrorAction SilentlyContinue) {
            # Initialize a list for JSON and non-JSON data
            $NonJSONData = New-Object System.Collections.Generic.List[String]
            $JSONData = New-Object System.Collections.Generic.List[Object]

            # Read the stderr log
            $ErrorLog = Get-Content -Path $stderrlog -ErrorAction SilentlyContinue
            foreach ($Line in $ErrorLog) {
                try {
                    # Attempt to parse the line as JSON
                    $JSONObject = $Line | ConvertFrom-Json 
                    $JSONData.Add($JSONObject)
                }
                catch {
                    # If parsing fails, add the line to the non-JSON data list
                    $NonJSONData.Add($Line)
                }
            }
        
            $NonJSONData | ForEach-Object {
                # Output each non-JSON line
                Write-Host -Object "$_"
            }

            $ErrorMsgs = $JSONData | Where-Object { $_.level -match "error" }
            if ($ErrorMsgs) {
                # Log an error if any error messages are found
                Write-Host -Object "[Error] An error has occurred during the Speedtest."
                $ExitCode = 1
            }

            $TextInfo = (Get-Culture).TextInfo
            $JSONData | ForEach-Object {
                if ($_.Message) {
                    # Output each JSON message
                    $Message = $_.Message
                    Write-Host -Object "[$($TextInfo.ToTitleCase($_.level))] $($_.timestamp) - $($Message.Trim())"
                }
            }
        }

        # Check if the stdout log file exists
        if (!(Test-Path -Path $stdoutlog -ErrorAction SilentlyContinue)) {
            Write-Host -Object "[Error] Failed to retrieve speedtest.exe output."
            exit 1
        }

        # Initialize lists to store speed test results
        $SpeedTestResults = New-Object System.Collections.Generic.List[Object]

        # Try to read the speed test results from the stdout log
        try {
            $InitialResultObject = Get-Content -Path $stdoutlog | ConvertFrom-Json -ErrorAction Stop
            if ($InitialResultObject) {
                $SpeedTestResults.Add($InitialResultObject)
            }
        }
        catch {
            Write-Host -Object "[Error] Error reading Speedtest results."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            exit 1
        }

        try {
            # Set error action preference to stop to handle any errors immediately
            $ErrorActionPreference = "Stop"
    
            # If there is no results to format, display an error message and exit
            if (!$SpeedTestResults) {
                Write-Host -Object "[Error] No Speedtest results found."
                exit 1
            }
    
            # Select the result with the highest download speed
            $BestResult = $SpeedTestResults | Sort-Object -Property @{e = { $_.download.bandwidth } } -Descending | Select-Object -First 1
    
            # If there is no download speed in the result, display an error message and exit
            if (!$BestResult.download.bandwidth) {
                Write-Host -Object "[Error] No Speedtest results found."
                exit 1
            }
    
            Write-Host -Object "`nAttempting to format results into a human readable format."
    
            # Match the MAC address to identify the network adapter used during the test
            $MacAddress = $BestResult.interface.macAddr -replace ':', '-'
            $NetAdapter = Get-NetAdapter | Where-Object { $_.MacAddress -match $MacAddress }
    
            # Determine the type of network connection (Wired, Wi-Fi, Other)
            $AdapterType = switch -Wildcard ($NetAdapter.MediaType) {
                "802.3" { "Wired" }
                "*802.11" { "Wi-Fi" }
                Default {
                    "Other"
                }
            }
    
    
            # Format the speed test results into a human-readable format
            $FormattedSpeedTestResult = [PSCustomObject]@{
                ResultUrl  = $BestResult.result.url
                ResultId   = $BestResult.result.id
                Date       = $BestResult.timestamp | Get-Date
                ISP        = $BestResult.isp
                Server     = "$($BestResult.server.name) ($($BestResult.server.id))"
                Down       = "$([System.Math]::Round($BestResult.download.bandwidth * 8 / 1000000,2)) Mbps"
                Up         = "$([System.Math]::Round($BestResult.upload.bandwidth * 8 / 1000000,2)) Mbps"
                Interface  = "$($NetAdapter.Name) - $AdapterType"
                MacAddress = $BestResult.interface.macAddr
                PacketLoss = $BestResult.packetLoss
                Jitter     = "$($BestResult.ping.jitter) ms"
                Latency    = "$($BestResult.ping.latency) ms"
                Low        = "$($BestResult.ping.low) ms"
                High       = "$($BestResult.ping.high) ms"
            }
    
            $ErrorActionPreference = "Continue"
        }
        catch {
            Write-Host -Object "[Error] Error selecting or formatting the results."
            Write-Host -Object "[Error] $($_.Exception.Message)"
            exit 1
        }

        # Output the result URL and detailed test results
        Write-Host -Object "`nResult URL: $($FormattedSpeedTestResult.ResultUrl)`n"
        ($FormattedSpeedTestResult | Format-List -Property Date, ISP, Server, Down, Up, Interface, MacAddress, PacketLoss, Jitter, Latency, Low, High | Out-String).Trim() | Write-Host

        # Attempt to clean up the downloaded files and SpeedTest CLI application
        try {
            Write-Host -Object "`nAttempting to cleanup downloaded files and cli app."
            Remove-Item -Path "$env:TEMP\speedtest.zip" -Force -ErrorAction Stop
            Remove-Item -Path "$env:TEMP\SpeedTest" -Recurse -Force -ErrorAction Stop
            Write-Host -Object "Successfully removed downloaded files and cli app."
        }
        catch {
            Write-Host -Object "[Error] Failed to clean up downloaded files at '$env:TEMP\SpeedTest' and '$env:TEMP\speedtest.zip'."
            $ExitCode = 1
        }
    }

    # If the WYSIWYG custom field is given, proceed to set and format the custom field.
    if ($WysiwygCustomField) {
        try {
            # Inform the user that the custom field is being set.
            Write-Host "`nAttempting to set Custom Field '$WysiwygCustomField'."

            $CompletedDateTime = Get-Date

            # Initialize the custom field value as a list of strings.
            $CustomFieldValue = New-Object System.Collections.Generic.List[String]

            # Convert the formatted CPU processes table to HTML and add custom formatting.
            $CPUProcessMetricTable = $FormattedProcesses | ConvertTo-Html -Fragment
            $CPUProcessMetricTable = $CPUProcessMetricTable -replace "<th>", "<th><b>" -replace "</th>", "</b></th>"
            $CPUProcessMetricTable = $CPUProcessMetricTable -replace "<table>", "<table><caption style='border-top: 1px; border-left: 1px; border-right: 1px; border-style: solid; border-color: #CAD0D6'><b>Top 5 CPU Processes</b></caption>"
            $CPUProcessMetricTable = $CPUProcessMetricTable -replace "Average CPU % Used", "<i class='fa-solid fa-arrow-down-up-across-line'></i>&nbsp;&nbsp;Average CPU % Used"
            $CPUProcessMetricTable = $CPUProcessMetricTable -replace "Minimum CPU % Used", "<i class='fa-solid fa-arrows-down-to-line'></i>&nbsp;&nbsp;Minimum CPU % Used"
            $CPUProcessMetricTable = $CPUProcessMetricTable -replace "Maximum CPU % Used", "<i class='fa-solid fa-arrows-up-to-line'></i>&nbsp;&nbsp;Maximum CPU % Used"

            # Highlight rows in the CPU table based on CPU usage thresholds (warnings and danger levels).
            $Top5CPUProcesses | ForEach-Object {
                if ($_.Avg -ge 20 -and $_.Avg -lt 50) { $CPUProcessMetricTable = $CPUProcessMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='warning'><td>$($_.InstanceName)" }
                if ($_.Min -ge 20 -and $_.Min -lt 50) { $CPUProcessMetricTable = $CPUProcessMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='warning'><td>$($_.InstanceName)" }
                if ($_.Max -ge 20 -and $_.Max -lt 50) { $CPUProcessMetricTable = $CPUProcessMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='warning'><td>$($_.InstanceName)" }

                if ($_.Avg -ge 50) { $CPUProcessMetricTable = $CPUProcessMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='danger'><td>$($_.InstanceName)" }
                if ($_.Min -ge 50) { $CPUProcessMetricTable = $CPUProcessMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='danger'><td>$($_.InstanceName)" }
                if ($_.Max -ge 50) { $CPUProcessMetricTable = $CPUProcessMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='danger'><td>$($_.InstanceName)" }
            }

            # Convert the formatted RAM processes table to HTML and add custom formatting.
            $RAMProcessMetricTable = $FormattedMemoryProcesses | ConvertTo-Html -Fragment
            $RAMProcessMetricTable = $RAMProcessMetricTable -replace "<th>", "<th><b>" -replace "</th>", "</b></th>"
            $RAMProcessMetricTable = $RAMProcessMetricTable -replace "<table>", "<table><caption style='border-top: 1px; border-left: 1px; border-right: 1px; border-style: solid; border-color: #CAD0D6'><b>Top 5 RAM Processes</b></caption>"
            $RAMProcessMetricTable = $RAMProcessMetricTable -replace "Average RAM % Used", "<i class='fa-solid fa-arrow-down-up-across-line'></i>&nbsp;&nbsp;Average RAM % Used"
            $RAMProcessMetricTable = $RAMProcessMetricTable -replace "Minimum RAM % Used", "<i class='fa-solid fa-arrows-down-to-line'></i>&nbsp;&nbsp;Minimum RAM % Used"
            $RAMProcessMetricTable = $RAMProcessMetricTable -replace "Maximum RAM % Used", "<i class='fa-solid fa-arrows-up-to-line'></i>&nbsp;&nbsp;Maximum RAM % Used"

            # Highlight rows in the RAM table based on RAM usage thresholds (warnings and danger levels).
            $Top5RAMProcesses | ForEach-Object {
                if ($_.Avg -ge 10 -and $_.Avg -lt 30) { $RAMProcessMetricTable = $RAMProcessMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='warning'><td>$($_.InstanceName)" }
                if ($_.Min -ge 10 -and $_.Min -lt 30) { $RAMProcessMetricTable = $RAMProcessMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='warning'><td>$($_.InstanceName)" }
                if ($_.Max -ge 10 -and $_.Max -lt 30) { $RAMProcessMetricTable = $RAMProcessMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='warning'><td>$($_.InstanceName)" }

                if ($_.Avg -ge 30) { $RAMProcessMetricTable = $RAMProcessMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='danger'><td>$($_.InstanceName)" }
                if ($_.Min -ge 30) { $RAMProcessMetricTable = $RAMProcessMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='danger'><td>$($_.InstanceName)" }
                if ($_.Max -ge 30) { $RAMProcessMetricTable = $RAMProcessMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='danger'><td>$($_.InstanceName)" }
            }

            # Convert the formatted I/O processes table to HTML and add custom formatting.
            $IOProcessesMetricTable = $FormattedIOProcesses | ConvertTo-Html -Fragment
            $IOProcessesMetricTable = $IOProcessesMetricTable -replace "<th>", "<th><b>" -replace "</th>", "</b></th>"
            $IOProcessesMetricTable = $IOProcessesMetricTable -replace "<table>", "<table><caption style='border-top: 1px; border-left: 1px; border-right: 1px; border-style: solid; border-color: #CAD0D6'><b>Top 5 IO Processes (Network & Disk Combined)</b></caption>"
            $IOProcessesMetricTable = $IOProcessesMetricTable -replace "Average IO Used", "<i class='fa-solid fa-arrow-down-up-across-line'></i>&nbsp;&nbsp;Average IO Used"
            $IOProcessesMetricTable = $IOProcessesMetricTable -replace "Minimum IO Used", "<i class='fa-solid fa-arrows-down-to-line'></i>&nbsp;&nbsp;Minimum IO Used"
            $IOProcessesMetricTable = $IOProcessesMetricTable -replace "Maximum IO Used", "<i class='fa-solid fa-arrows-up-to-line'></i>&nbsp;&nbsp;Maximum IO Used"

            # Highlight rows in the I/O table based on I/O usage thresholds (warnings and danger levels).
            $Top5IOProcesses | ForEach-Object {
                if ($_.Avg -ge 1250000 -and $_.Avg -lt 12500000) { $IOProcessesMetricTable = $IOProcessesMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='warning'><td>$($_.InstanceName)" }
                if ($_.Min -ge 1250000 -and $_.Min -lt 12500000) { $IOProcessesMetricTable = $IOProcessesMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='warning'><td>$($_.InstanceName)" }
                if ($_.Max -ge 1250000 -and $_.Max -lt 12500000) { $IOProcessesMetricTable = $IOProcessesMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='warning'><td>$($_.InstanceName)" }

                if ($_.Avg -ge 12500000) { $IOProcessesMetricTable = $IOProcessesMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='danger'><td>$($_.InstanceName)" }
                if ($_.Min -ge 12500000) { $IOProcessesMetricTable = $IOProcessesMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='danger'><td>$($_.InstanceName)" }
                if ($_.Max -ge 12500000) { $IOProcessesMetricTable = $IOProcessesMetricTable -replace "<tr><td>$($_.InstanceName)", "<tr class='danger'><td>$($_.InstanceName)" }
            }

            # Convert the formatted network usage table to HTML and add custom formatting.
            $NetworkUsageMetricTable = $FormattedNetworkUsage | ConvertTo-Html -Fragment
            $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "<th>", "<th><b>" -replace "</th>", "</b></th>"
            $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "<table>", "<table><caption style='border-top: 1px; border-left: 1px; border-right: 1px; border-style: solid; border-color: #CAD0D6'><b>Network Usage</b></caption>"
            $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "Average Sent & Received", "<i class='fa-solid fa-arrow-down-up-across-line'></i>&nbsp;&nbsp;Average Sent & Received"
            $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "Minimum Sent & Received", "<i class='fa-solid fa-arrows-down-to-line'></i>&nbsp;&nbsp;Minimum Sent & Received"
            $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "Maximum Sent & Received", "<i class='fa-solid fa-arrows-up-to-line'></i>&nbsp;&nbsp;Maximum Sent & Received"

            # Add network type icons for wired, Wi-Fi, and other network interfaces.
            $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "<th><b>Type</b></th>", "<th><b><i class='fa-solid fa-network-wired'></i>&nbsp;&nbsp;Type</b></th>"
            $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "<td>Wired</td>", "<td><i class='fa-solid fa-ethernet'></i>&nbsp;&nbsp;Wired</td>"
            $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "<td>Wi-Fi</td>", "<td><i class='fa-solid fa-wifi'></i>&nbsp;&nbsp;Wi-Fi</td>"
            $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "<td>Other</td>", "<td><i class='fa-solid fa-circle-question'></i>&nbsp;&nbsp;Other</td>"

            # Highlight network interfaces based on network usage thresholds and interface types.
            $NetworkInterfaceUsage | ForEach-Object {
                if ($_.Avg -ge 1250000 -and $_.Avg -lt 12500000) { $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "<tr><td>$($_.NetworkAdapter)", "<tr class='warning'><td>$($_.NetworkAdapter)" }
                if ($_.Min -ge 1250000 -and $_.Min -lt 12500000) { $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "<tr><td>$($_.NetworkAdapter)", "<tr class='warning'><td>$($_.NetworkAdapter)" }
                if ($_.Max -ge 1250000 -and $_.Max -lt 12500000) { $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "<tr><td>$($_.NetworkAdapter)", "<tr class='warning'><td>$($_.NetworkAdapter)" }

                if ($_.Avg -ge 12500000) { $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "<tr><td>$($_.NetworkAdapter)", "<tr class='danger'><td>$($_.NetworkAdapter)" }
                if ($_.Min -ge 12500000) { $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "<tr><td>$($_.NetworkAdapter)", "<tr class='danger'><td>$($_.NetworkAdapter)" }
                if ($_.Max -ge 12500000) { $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "<tr><td>$($_.NetworkAdapter)", "<tr class='danger'><td>$($_.NetworkAdapter)" }

                # Highlight Wi-Fi or "Other" types as warnings.
                if ($_.Type -eq "Wi-Fi" -or $_.Type -eq "Other") {
                    $NetworkUsageMetricTable = $NetworkUsageMetricTable -replace "<tr><td>$($_.NetworkAdapter)", "<tr class='warning'><td>$($_.NetworkAdapter)"
                }
            }

            # Convert the formatted disk usage table to HTML and add custom formatting.
            $DiskMetricTable = $FormattedDiskMetrics | ConvertTo-Html -Fragment
            $DiskMetricTable = $DiskMetricTable -replace "<th>", "<th><b>" -replace "</th>", "</b></th>"
            $DiskMetricTable = $DiskMetricTable -replace "<table>", "<table><caption style='border-top: 1px; border-left: 1px; border-right: 1px; border-style: solid; border-color: #CAD0D6'><b>Disk Usage</b></caption>"
            $DiskMetricTable = $DiskMetricTable -replace "Average IOPS", "<i class='fa-solid fa-arrow-down-up-across-line'></i>&nbsp;&nbsp;Average IOPS"
            $DiskMetricTable = $DiskMetricTable -replace "Minimum IOPS", "<i class='fa-solid fa-arrows-down-to-line'></i>&nbsp;&nbsp;Minimum IOPS"
            $DiskMetricTable = $DiskMetricTable -replace "Maximum IOPS", "<i class='fa-solid fa-arrows-up-to-line'></i>&nbsp;&nbsp;Maximum IOPS"

            # Highlight rows in the disk usage table based on drive type and available space thresholds.
            $DiskMetrics | ForEach-Object {
                if ($_.MediaType -ne "SSD" -and $_.MediaType -ne "Unspecified") {
                    $DiskMetricTable = $DiskMetricTable -replace "<tr><td>$($_.DriveLetter)", "<tr class='danger'><td>$($_.DriveLetter)"
                }

                if ($_.FreeSpaceGB -lt 100) {
                    $DiskMetricTable = $DiskMetricTable -replace "<tr><td>$($_.DriveLetter)", "<tr class='warning'><td>$($_.DriveLetter)"
                }

                if ($_.FreeSpaceGB -lt 10) {
                    $DiskMetricTable = $DiskMetricTable -replace "<tr class='warning'><td>$($_.DriveLetter)", "<tr class='danger'><td>$($_.DriveLetter)"
                }
            }

            # Handle WinSAT assessment data if it's valid and add the WinSAT scores to the table.
            $ValidAssessmentStates = "1", "2"
            if ($ValidAssessmentStates -contains $WinSatScores.WinSATAssessmentState) {
                $WinSATMetricTable = $WinSatScores | Select-Object -Property CPUScore, D3DScore, DiskScore, GraphicsScore, MemoryScore | ConvertTo-Html -Fragment
                $WinSATMetricTable = $WinSATMetricTable -replace "<th>", "<th><b>" -replace "</th>", "</b></th>"
                $WinSATMetricTable = $WinSATMetricTable -replace "<table>", "<br><table><caption style='border-top: 1px; border-left: 1px; border-right: 1px; border-style: solid; border-color: #CAD0D6'><b>WinSAT Scores</b></caption>"

                # Highlight rows in the WinSAT table based on score thresholds.
                if ($WinSatScores.CPUScore -lt 7 -or $WinSatScores.D3DScore -lt 7 -or $WinSatScores.DiskScore -lt 7 -or $WinSatScores.GraphicsScore -lt 7 -or $WinSatScores.MemoryScore -lt 7) {
                    $WinSATMetricTable = $WinSATMetricTable -replace "<tr><td>", "<tr class='warning'><td>"
                }

                if ($WinSatScores.CPUScore -lt 4 -or $WinSatScores.D3DScore -lt 4 -or $WinSatScores.DiskScore -lt 4 -or $WinSatScores.GraphicsScore -lt 4 -or $WinSatScores.MemoryScore -lt 4) {
                    $WinSATMetricTable = $WinSATMetricTable -replace "<tr class='warning'><td>", "<tr class='danger'><td>"
                }
            }
            else {
                # If WinSAT data is not available, display a message.
                $WinSATMetricTable = "<p style='margin-top: 0px'>The WinSAT assessment data is either invalid or not available for this computer.</p>"
            }

            # Create the HTML content for the performance metrics section.
            $HTMLCard = "<div class='card flex-grow-1'>
    <div class='card-title-box'>
        <div class='card-title'><i class='fa-solid fa-gauge-high'></i>&nbsp;&nbsp;System Performance Metrics</div>
    </div>
    <div class='card-body' style='white-space: nowrap'>
        <table style='border: 0px; justify-content: space-evenly; white-space: nowrap;'>
            <tbody>
                <tr>
                    <td style='border: 0px; white-space: nowrap; padding-left: 0px;'>
                        <p class='card-text'><b>Start Date and Time</b><br>$($StartedDateTime.ToShortDateString()) $($StartedDateTime.ToShortTimeString())</p>
                    </td>
                    <td style='border: 0px; white-space: nowrap;'>
                        <p class='card-text'><b>Completed Date and Time</b><br>$($CompletedDateTime.ToShortDateString()) $($CompletedDateTime.ToShortTimeString())</p>
                    </td>
                </tr>
            </tbody>
        </table>
        <p id='lastStartup' class='card-text'><b>Last Startup Time</b><br>$($LastStartTime.ToShortDateString()) $($LastStartTime.ToShortTimeString())</p>
        <p><b>$CPU</b></p>
        <table style='border: 0px;'>
            <tbody>
                <tr>
                    <td style='border: 0px; white-space: nowrap'>
                        <div class='stat-card' style='display: flex;'>
                            <div class='stat-value' id='cpuOverallAvg' style='color: #008001;'>$($FormattedCPUPerformance."CPU Average %")</div>
                            <div class='stat-desc'><i class='fa-solid fa-arrow-down-up-across-line'></i>&nbsp;&nbsp;Average CPU % Used</div>
                        </div>
                    </td>
                    <td style='border: 0px; white-space: nowrap'>
                        <div class='stat-card' style='display: flex;'>
                            <div class='stat-value' id='cpuOverallMin' style='color: #008001;'>$($FormattedCPUPerformance."CPU Minimum %")</div>
                            <div class='stat-desc'><i class='fa-solid fa-arrows-down-to-line'></i>&nbsp;&nbsp;Minimum CPU % Used</div>
                        </div>
                    </td>
                    <td style='border: 0px; white-space: nowrap'>
                        <div class='stat-card' style='display: flex;'>
                            <div class='stat-value' id='cpuOverallMax' style='color: #008001;'>$($FormattedCPUPerformance."CPU Maximum %")</div>
                            <div class='stat-desc'><i class='fa-solid fa-arrows-up-to-line'></i>&nbsp;&nbsp;Maximum CPU % Used</div>
                        </div>
                    </td>
                </tr>
            </tbody>
        </table>
        <p><b>Total Memory: $TotalMemoryGB</b></p>
        <table style='border: 0px;'>
            <tbody>
                <tr>
                    <td style='border: 0px; white-space: nowrap'>
                        <div class='stat-card' style='display: flex;'>
                            <div class='stat-value' id='ramOverallAvg' style='color: #008001;'>$($OverallMemoryMetrics."RAM Average %")</div>
                            <div class='stat-desc'><i class='fa-solid fa-arrow-down-up-across-line'></i>&nbsp;&nbsp;Average RAM % Used</div>
                        </div>
                    </td>
                    <td style='border: 0px; white-space: nowrap'>
                        <div class='stat-card' style='display: flex;'>
                            <div class='stat-value' id='ramOverallMin' style='color: #008001;'>$($OverallMemoryMetrics."RAM Minimum %")</div>
                            <div class='stat-desc'><i class='fa-solid fa-arrows-down-to-line'></i>&nbsp;&nbsp;Minimum RAM % Used</div>
                        </div>
                    </td>
                    <td style='border: 0px; white-space: nowrap'>
                        <div class='stat-card' style='display: flex;'>
                            <div class='stat-value' id='ramOverallMax' style='color: #008001;'>$($OverallMemoryMetrics."RAM Maximum %")</div>
                            <div class='stat-desc'><i class='fa-solid fa-arrows-up-to-line'></i>&nbsp;&nbsp;Maximum RAM % Used</div>
                        </div>
                    </td>
                </tr>
            </tbody>
        </table>
        $CPUProcessMetricTable
        <br>
        $RAMProcessMetricTable
        <br>
        $NetworkUsageMetricTable
        <br>
        $DiskMetricTable
        <br>
        $IOProcessesMetricTable
        $(if($ValidAssessmentStates -notcontains $WinSatScores.WinSATAssessmentState) {"<p style='margin-bottom: 0px'><b>WinSAT Scores</b></p>"})
        $WinSATMetricTable
    </div>
</div>"
            # Modify the last startup time section based on whether the startup limit was exceeded or not.
            if ($ExceededLastStartupLimit) {
                $HTMLCard = $HTMLCard -replace "id='lastStartup' class='card-text'><b>Last Startup Time</b><br>$($LastStartTime.ToShortDateString()) $($LastStartTime.ToShortTimeString())", "id='lastStartup' class='card-text'><b>Last Startup Time</b><br>$($LastStartTime.ToShortDateString()) $($LastStartTime.ToShortTimeString())&nbsp;&nbsp;<i class='fa-solid fa-circle-exclamation' style='color: #D53948;'></i>"
            }
            elseif ($DaysSinceLastReboot -ge 0) {
                $HTMLCard = $HTMLCard -replace "id='lastStartup' class='card-text'><b>Last Startup Time</b><br>$($LastStartTime.ToShortDateString()) $($LastStartTime.ToShortTimeString())", "id='lastStartup' class='card-text'><b>Last Startup Time</b><br>$($LastStartTime.ToShortDateString()) $($LastStartTime.ToShortTimeString())&nbsp;&nbsp;<i class='fa-solid fa-circle-check' style='color: #008001;'></i>"
            }

            # Highlight CPU performance metrics based on threshold values (color coding).
            if ($CPUPerformance.Avg -ge 60 -and $CPUPerformance.Avg -lt 90) { $HTMLCard = $HTMLCard -replace "id='cpuOverallAvg' style='color: #008001;'", "id='cpuOverallAvg' style='color: #FAC905;'" }
            if ($CPUPerformance.Min -ge 60 -and $CPUPerformance.Min -lt 90) { $HTMLCard = $HTMLCard -replace "id='cpuOverallMin' style='color: #008001;'", "id='cpuOverallMin' style='color: #FAC905;'" }
            if ($CPUPerformance.Max -ge 60 -and $CPUPerformance.Max -lt 90) { $HTMLCard = $HTMLCard -replace "id='cpuOverallMax' style='color: #008001;'", "id='cpuOverallMax' style='color: #FAC905;'" }

            if ($CPUPerformance.Avg -ge 90) { $HTMLCard = $HTMLCard -replace "id='cpuOverallAvg' style='color: #008001;'", "id='cpuOverallAvg' style='color: #D53948;'" }
            if ($CPUPerformance.Min -ge 90) { $HTMLCard = $HTMLCard -replace "id='cpuOverallMin' style='color: #008001;'", "id='cpuOverallMin' style='color: #D53948;'" }
            if ($CPUPerformance.Max -ge 90) { $HTMLCard = $HTMLCard -replace "id='cpuOverallMax' style='color: #008001;'", "id='cpuOverallMax' style='color: #D53948;'" }

            # Highlight RAM performance metrics based on threshold values (color coding).
            if ($MemoryPerformance.Avg -ge 60 -and $MemoryPerformance.Avg -lt 90) { $HTMLCard = $HTMLCard -replace "id='ramOverallAvg' style='color: #008001;'", "id='ramOverallAvg' style='color: #FAC905;'" }
            if ($MemoryPerformance.Min -ge 60 -and $MemoryPerformance.Min -lt 90) { $HTMLCard = $HTMLCard -replace "id='ramOverallMin' style='color: #008001;'", "id='ramOverallMin' style='color: #FAC905;'" }
            if ($MemoryPerformance.Max -ge 60 -and $MemoryPerformance.Max -lt 90) { $HTMLCard = $HTMLCard -replace "id='ramOverallMax' style='color: #008001;'", "id='ramOverallMax' style='color: #FAC905;'" }

            if ($MemoryPerformance.Avg -ge 90) { $HTMLCard = $HTMLCard -replace "id='ramOverallAvg' style='color: #008001;'", "id='ramOverallAvg' style='color: #D53948;'" }
            if ($MemoryPerformance.Min -ge 90) { $HTMLCard = $HTMLCard -replace "id='ramOverallMin' style='color: #008001;'", "id='ramOverallMin' style='color: #D53948;'" }
            if ($MemoryPerformance.Max -ge 90) { $HTMLCard = $HTMLCard -replace "id='ramOverallMax' style='color: #008001;'", "id='ramOverallMax' style='color: #D53948;'" }

            # Add the created HTML card to the custom field.
            $CustomFieldValue.Add($HTMLCard)

            # Check if there are any event logs to display.
            if ($NumberOfEvents -gt 0 -and $EventLogs.Count -gt 0) {
                # Convert the event logs into an HTML fragment for displaying in the output.
                $EventLogTableMetrics = $EventLogs | ConvertTo-Html -Fragment

                # Apply custom styles to the HTML table headers.
                $EventLogTableMetrics = $EventLogTableMetrics -replace "<th>", "<th><b>" -replace "</th>", "</b></th>"

                # Set specific column widths for better presentation.
                $EventLogTableMetrics = $EventLogTableMetrics -replace "<th><b>LogName", "<th style='width: 100px'><b>Log Name"
                $EventLogTableMetrics = $EventLogTableMetrics -replace "<th><b>ProviderName", "<th style='width: 250px'><b>Provider Name"
                $EventLogTableMetrics = $EventLogTableMetrics -replace "<th><b>Id", "<th style='width: 75px'><b>Id"
                $EventLogTableMetrics = $EventLogTableMetrics -replace "<th><b>TimeCreated", "<th style='width: 175px'><b>Time Created"
            }
            elseif ($NumberOfEvents -gt 0) {
                # If no events were found, display a message instead of the table.
                $EventLogTableMetrics = "<p style='margin-top: 0px'>No error events were found in the event log.</p>"
            }

            # If event logs exist, create a card to display them.
            if ($NumberOfEvents -gt 0) {
                # Create the HTML structure for the event log card.
                $EventLogCard = "<div class='card flex-grow-1'>
    <div class='card-title-box'>
        <div class='card-title'><i class='fa-solid fa-book'></i>&nbsp;&nbsp;Recent Error Events</div>
    </div>
    <div class='card-body' style='white-space: nowrap'>
        $EventLogTableMetrics
    </div>
</div>"
                # Add the event log card to the custom field value.
                $CustomFieldValue.Add($EventLogCard)
            }

            # If a speed test was performed, create a card to display the results.
            if ($SpeedTest) {
                # Create the HTML content for the Speedtest results.
                $SpeedTestCard = "<div class='card flex-grow-1'>
    <div class='card-title-box'>
        <div class='card-title'><i class='fa-solid fa-gauge-high'></i>&nbsp;&nbsp;Speedtest Results</div>
        <div class='card-link-box'>
            <a href='$($FormattedSpeedTestResult.ResultUrl)' target='_blank' class='card-link' rel='nofollow noopener noreferrer'>
                <i class='fas fa-arrow-up-right-from-square' style='color: #337ab7;'></i>
            </a>
        </div>
    </div>
    <div class='card-body' style='white-space: nowrap'>
        <table style='border: 0px; justify-content: space-evenly; white-space: nowrap;'>
            <tbody>
                <tr>
                    <td style='border: 0px; white-space: nowrap;'>
                        <p class='card-text'><b>Date</b><br>$($FormattedSpeedTestResult.Date)</p>
                    </td>
                    <td style='border: 0px; white-space: nowrap;'>
                        <p class='card-text'><b>ISP</b><br>$($FormattedSpeedTestResult.ISP)</p>
                    </td>
                    <td style='border: 0px; white-space: nowrap;'>
                        <p class='card-text'><b>Speedtest Server</b><br>$($FormattedSpeedTestResult.Server)</p>
                    </td>
                    <td style='border: 0px; white-space: nowrap;'>
                        <p class='card-text'><b>$($FormattedSpeedTestResult.Interface)</b><br><i class='fa-solid fa-ethernet'></i>&nbsp;&nbsp;$($FormattedSpeedTestResult.MacAddress)</p>
                    </td>
                </tr>
            </tbody>
        </table>
        <table style='border: 0px;'>
            <tbody>
                <tr>
                    <td style='border: 0px; white-space: nowrap'>
                        <div class='stat-card' style='display: flex;'>
                            <div class='stat-value' style='color: #008001;'>$($FormattedSpeedTestResult.Down)</div>
                            <div class='stat-desc'><i class='fa-solid fa-circle-down'></i>&nbsp;&nbsp;Download</div>
                        </div>
                    </td>
                    <td style='border: 0px; white-space: nowrap'>
                        <div class='stat-card' style='display: flex;'>
                            <div class='stat-value' style='color: #008001;'>$($FormattedSpeedTestResult.Up)</div>
                            <div class='stat-desc'><i class='fa-solid fa-circle-up'></i>&nbsp;&nbsp;Upload</div>
                        </div>
                    </td>
                    <td style='border: 0px; white-space: nowrap'>
                        <div class='stat-card' style='display: flex;'>
                            <div class='stat-value' style='color: #008001;'>$($FormattedSpeedTestResult.Jitter)</div>
                            <div class='stat-desc'><i class='fa-solid fa-chart-line'></i>&nbsp;&nbsp;Jitter</div>
                        </div>
                    </td>
                </tr>
            </tbody>
        </table>
        <table style='border: 0px;'>
            <tbody>
                <tr>
                    <td style='border: 0px; white-space: nowrap'>
                        <div class='stat-card' style='display: flex;'>
                            <div class='stat-value' style='color: #008001;'>$($FormattedSpeedTestResult.Latency)</div>
                            <div class='stat-desc'><i class='fa-solid fa-server'></i>&nbsp;&nbsp;Latency</div>
                        </div>
                    </td>
                    <td style='border: 0px; white-space: nowrap'>
                        <div class='stat-card' style='display: flex;'>
                            <div class='stat-value' style='color: #008001;'>$($FormattedSpeedTestResult.High)</div>
                            <div class='stat-desc'><i class='fa-solid fa-chevron-up'></i>&nbsp;&nbsp;High</div>
                        </div>
                    </td>
                    <td style='border: 0px; white-space: nowrap'>
                        <div class='stat-card' style='display: flex;'>
                            <div class='stat-value' style='color: #008001;'>$($FormattedSpeedTestResult.Low)</div>
                            <div class='stat-desc'><i class='fa-solid fa-chevron-down'></i>&nbsp;&nbsp;Low</div>
                        </div>
                    </td>
                </tr>
            </tbody>
        </table>
    </div>
</div>
"

                # Adjust the icon based on the adapter type (e.g., Wired, Wi-Fi, or Other).
                switch ($AdapterType) {
                    "Wi-Fi" {
                        # Replace the Ethernet icon with a Wi-Fi icon if the adapter type is Wi-Fi.
                        $SpeedTestCard = $SpeedTestCard -replace 'fa-solid fa-ethernet', 'fa-solid fa-wifi'
                    }
                    "Other" {
                        # Replace the Ethernet icon with a question mark icon for "Other" adapter types.
                        $SpeedTestCard = $SpeedTestCard -replace 'fa-solid fa-ethernet', 'fa-solid fa-circle-question'
                    }
                }

                # Add the Speedtest card to the custom field value.
                $CustomFieldvalue.Add($SpeedTestCard)
            }

            # Check if the HTML content exceeds the character limit (200,000 characters).
            $HTMLCharacters = $CustomFieldValue | ConvertTo-Json | Measure-Object -Character | Select-Object -ExpandProperty Characters
            if ($HTMLCharacters -ge 195000) {
                Write-Warning "200,000 Character Limit has been reached! Trimming output until the character limit is satisfied..."
                    
                # Truncate the output if it exceeds the limit.
                $i = 0
                [array]$NewEventLogTable = $EventLogTableMetrics
                do {
                    # Recreate the custom field output
                    $CustomFieldValue = New-Object System.Collections.Generic.List[string]
                    if (!$NumberOfEvents -or !$NumberOfEvents -gt 0 -or !$EventLogs.Count -gt 0) {
                        Write-Host -Object "[Error] No events to trim."
                        exit 1
                    }

                    # Add the main performance metrics card to the custom field.
                    $CustomFieldValue.Add($HTMLCard)
    
                    # Reverse the event log array so that the last entry is at the top.
                    [array]::Reverse($NewEventLogTable)

                    # Delete rows until the character count is reduced.
                    if ($NewEventLogTable[$i] -match '<tr><td>' -or $NewEventLogTable[$i] -match '<tr class=') {
                        $NewEventLogTable[$i] = $null
                    }
                    $i++
                    
                    # Reverse the array back to its original order.
                    [array]::Reverse($NewEventLogTable)

                    # Rebuild the event log card with the truncated log.
                    $EventLogCard = "<div class='card flex-grow-1'>
    <div class='card-title-box'>
        <div class='card-title'><i class='fa-solid fa-book'></i>&nbsp;&nbsp;Recent Error Events</div>
    </div>
    <div class='card-body' style='white-space: nowrap'>
        $NewEventLogTable
    </div>
</div>"

                    # Add a truncation notice and the truncated event log card.
                    $CustomFieldValue.Add("<h1>This info has been truncated to accommodate the 200,000 character limit.</h1>")
                    $CustomFieldValue.Add($EventLogCard)

                    # Add the Speedtest card if it was run.
                    if ($SpeedTest) {
                        $CustomFieldValue.Add($SpeedTestCard)
                    }

                    # Check the character count again; repeat if still too long.
                    $HTMLCharacters = $CustomFieldValue | ConvertTo-Json | Measure-Object -Character | Select-Object -ExpandProperty Characters
                }while ($HTMLCharacters -ge 195000)
            }

            # Set the custom field with the finalized HTML content.
            Set-NinjaProperty -Name $WysiwygCustomField -Value $CustomFieldValue
            Write-Host "Successfully set Custom Field '$WysiwygCustomField'!"
        }
        catch {
            Write-Host "[Error] $($_.Exception.Message)"
            $ExitCode = 1
        }
    }

    # If the $NumberOfEvents variable has a value, proceed to display the event logs.
    if ($NumberOfEvents) {
        # Display a message indicating the number of errors retrieved from the event logs.
        Write-Host -Object "`n### Last $NumberOfEvents errors in Application, Security, Setup and System Log. ###"

        # Format and display the collected event logs in a list format.
        ($EventLogs | Format-List | Out-String).Trim() | Write-Host
    }

    # Try to remove the lock file to ensure no other instance of the script is running.
    try {
        Remove-Item -Path "$env:ProgramData\NinjaRMMAgent\SystemPerformance.lock.txt" -Force -ErrorAction Stop
    }
    catch {
        # If the removal of the lock file fails, catch the exception and display error messages.
        Write-Host -Object "[Error] Failed to remove lock file at '$env:ProgramData\NinjaRMMAgent\SystemPerformance.lock.txt'."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        $ExitCode = 1
    }

}
end {
    
    
    
}