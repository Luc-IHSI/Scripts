$dirError = "directory does not exist:"
$dirsData = @("C:\Windows\System32\drivers\SentinelOne", "C:\ProgramData\Sentinel", "C:\Program Files\SentinelOne")
$dirNinja = "C:\ProgramData\NinjaRMMAgent"
$dirSenti = "components\sentinelone"
$subDirNS = Join-Path $dirNinja $dirSenti
$senToken = $env:s1SiteToken
$senQuiet = $env:s1QuietRepair
$senModeR = $env:s1RebootMode # Should be "Auto", "Force", or "None".
$senDelay = [System.Convert]::ToInt32(($env:s1RebootDelay, "120")[[string]::IsNullOrEmpty($env:s1RebootDelay)])
$senQuiet = [System.Convert]::ToBoolean(($env:s1QuietRepair, "false")[[string]::IsNullOrEmpty($env:s1QuietRepair)])

# Verbose logging
$WarningPreference = "Continue"
$VerbosePreference = "Continue"
$DebugPreference = "Continue"

# See: https://usea1-ninjaone.sentinelone.net/docs/en/windows-agent-installer-command-line-options.html
#
# --force
# --ignore_pending_reboot_request
# -b, --reboot_on_need
# -a "/REBOOT"
#     Pass /REBOOT to installer args
# --stateless_upgrade <>
#     Executing a stateless upgrade (when possible, proceeding to re-installation after cleaning without rebooting)
# --dont_fail_on_config_preserving_failures
#     Don't fail when failing on retrieving previous Agent's configurations (Stateless Upgrade)
# -q
#     Quiet install, don't show UI
#
# Useful installer args:
# /FORCERESTART
# /NORESTART
# /REBOOT
$senArgs = @(
    "--force",
    "--wait",
    "--dont_preserve_config_dir",
    "--dont_preserve_agent_uid",
    "--dont_preserve_proxy",
    "-c"
)
# Enable automatic reboot, remove -b if you change REBOOT to NORESTART
switch ($senModeR) {
    "None" {
        $senArgs += @("-a", "/NORESTART", "--ignore_pending_reboot_request")
    }
    "Force" {
        $senArgs += @("-a", "/FORCERESTART", "-b")
    }
    default {
        $senArgs += @("-a", "/REBOOT", "-b")
    }
}

function Invoke-SilentProcess {
    param (
        [Parameter(Mandatory)]
        [string]$Path,
        [string]$WorkingDirectory,
        [string]$Token,
        [string[]]$ArgumentList = @(),
        [switch]$Quiet
    )

    begin {
        $WarningPreference = "Continue"
        $VerbosePreference = "Continue"
        $DebugPreference = "Continue"
    }

    process {
        Write-Host "Invoke-SilentProcess started..." -ForegroundColor Cyan

        # Enable quiet mode, handle Ninja checkbox
        if ($Quiet -or $senQuiet) {
            $ArgumentList += "-q"
        }

        [PSCustomObject]@{
            "Path" = $Path
            "WorkingDirectory" = $WorkingDirectory
            "Token" = "[redacted, $($Token.Length) chars long]"
            "ArgumentList" = "[" + $($ArgumentList -join ", ") + "]"
        } | Format-List | Out-String | Write-Debug

        # Add token after logging
        $ArgumentList += @("-t", "`"$Token`"")

        # Start the process in the current window to see output directly
        $process = Start-Process -FilePath $Path `
            -WorkingDirectory $WorkingDirectory `
            -ArgumentList $ArgumentList `
            -NoNewWindow `
            -PassThru `
            -Wait

        Write-Host "Process completed with exit code: $($process.ExitCode)" -ForegroundColor Cyan
        return $process.ExitCode
    }
}

function Invoke-RebootOnDemand {
    param (
        [bool]$Condition = $false,
        [int]$Delay = 0
    )

    if ($Condition) {
        Write-Host "Finished SentinelOne repair, going to reboot in $Delay seconds..." -ForegroundColor Green

        if ($Delay -le 1) {
            Restart-Computer -Confirm:$false -Force
        } else {
            Shutdown.exe /F /R /T $Delay
        }
    } else {
        Write-Host "Finished SentinelOne repair, please reboot the machine before reinstalling." -ForegroundColor Green
    }
}

function Write-ErrorDetails {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    process {
        Write-Host "======= ERROR DETAILS =======" -ForegroundColor Red

        # Basic error information
        Write-Host "Error Message: $($ErrorRecord)" -ForegroundColor Yellow
        Write-Host "Category Info: $($ErrorRecord.CategoryInfo)" -ForegroundColor Yellow

        # Stack trace information
        Write-Host "`n--- Stack Trace ---" -ForegroundColor Cyan
        Write-Host $ErrorRecord.ScriptStackTrace

        # Exception details
        Write-Host "`n--- Exception Details ---" -ForegroundColor Cyan
        Write-Host "Type: $($ErrorRecord.Exception.GetType().FullName)"
        Write-Host "Message: $($ErrorRecord.Exception.Message)"

        # InnerException (if exists)
        if ($ErrorRecord.Exception.InnerException) {
            Write-Host "`n--- Inner Exception ---" -ForegroundColor Cyan
            Write-Host "Type: $($ErrorRecord.Exception.InnerException.GetType().FullName)"
            Write-Host "Message: $($ErrorRecord.Exception.InnerException.Message)"
        }

        # Position information
        Write-Host "`n--- Position Info ---" -ForegroundColor Cyan
        Write-Host "Script: $($ErrorRecord.InvocationInfo.ScriptName)"
        Write-Host "Line Number: $($ErrorRecord.InvocationInfo.ScriptLineNumber)"
        Write-Host "Position: $($ErrorRecord.InvocationInfo.PositionMessage)"
        Write-Host "Line: $($ErrorRecord.InvocationInfo.Line)"
    }
}

function Get-SentinelToken {
    begin {
        $WarningPreference = "Continue"
        $VerbosePreference = "Continue"
        $DebugPreference = "Continue"
    }

    process {
        Add-Type -AssemblyName PresentationFramework

        # XAML for the form
        [xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Security Token" Height="200" Width="350" WindowStartupLocation="CenterScreen">
    <Grid>
        <Label Content="Enter SentinelOne site token:" HorizontalAlignment="Left" Margin="10,20,0,0" VerticalAlignment="Top"/>
        <PasswordBox x:Name="TokenPasswordBox" HorizontalAlignment="Left" Height="23" Margin="10,50,0,0" VerticalAlignment="Top" Width="310"/>
        <Button x:Name="OkButton" Content="OK" HorizontalAlignment="Left" Margin="85,100,0,0" VerticalAlignment="Top" Width="75" IsDefault="True"/>
        <Button x:Name="CancelButton" Content="Cancel" HorizontalAlignment="Left" Margin="180,100,0,0" VerticalAlignment="Top" Width="75" IsCancel="True"/>
    </Grid>
</Window>
"@

        # Create the form
        $reader = New-Object System.Xml.XmlNodeReader $xaml
        $form = [Windows.Markup.XamlReader]::Load($reader)

        # Get form elements
        $tokenPasswordBox = $form.FindName("TokenPasswordBox")
        $okButton = $form.FindName("OkButton")
        $cancelButton = $form.FindName("CancelButton")

        # Define actions
        $okButton.Add_Click({
            $form.DialogResult = $true
            $form.Close()
        })

        $cancelButton.Add_Click({
            $form.DialogResult = $false
            $form.Close()
        })

        # Show the form
        $result = $form.ShowDialog()

        # Process the result
        if ($result) {
            return $tokenPasswordBox.Password
        }

        return ""
    }
}

# Check if we have a site token
if (-not $senToken) {
    # Use GUI to get token
    if (-not $senToken) {
        $senToken = Get-SentinelToken
    }

    Write-Error "SentinelOne Site Token was not provided."
    exit 1
}

# Check NinjaRMMAgent dir exists
if (-not $(Test-Path $dirNinja)) {
    Write-Error "$dirError $dirNinja"
    exit 1
}

# Check sentinelone download dir exists
if (-not $(Test-Path $subDirNS)) {
    Write-Error "$dirError $subDirNS"
    exit 1
}

# Get dirs inside download dir
$dirs = Get-ChildItem -Path $subDirNS -Attributes Directory

# Check if we have anything other than the regular sentinelone installer directory
# TODO: Handle this by checking which one is correct
if ($dirs.Count -ne 1) {
    Write-Error "Got $($dirs.Count) directories, expected 1"
    $dirs | Format-List | Out-String | Write-Error
    exit 1
}

$sig = 0
try {
    # Get exes inside installer dir
    $exePath = Join-Path $subDirNS $dirs[0]
    $exes = Get-ChildItem -Path $exePath -Filter "*.exe"
    Write-Host "Got exe path: $exePath`n`t[$($exes -join ", ")]"

    # Check if we have anything other than the regular sentinelone installer
    # TODO: Handle this by checking which one is correct
    if ($exes.Count -ne 1) {
        Write-Error "Got $($dirs.Count) executables, expected 1"
        $exes | Format-List | Out-String | Write-Error
        exit 1
    }

    # Get full exe path
    #    $exeName = $exes[0].Name
    $exeFile = Join-Path $exePath $exes[0].Name -Resolve

    $sig = Invoke-SilentProcess `
        -Path $exeFile `
        -WorkingDirectory $exePath `
        -Token $senToken `
        -ArgumentList $senArgs
}
catch {
    $_ | Write-ErrorDetails
}

switch ($sig) {
    0 {
        Write-Host "Removing SentinelOne directories..." -ForegroundColor Cyan
        $res = $false

        foreach ($dir in $dirsData) {
            if (Test-Path $dir) {
                Write-Host "Removing ${dir}..." -ForegroundColor Yellow
                Remove-Item $dir -Recurse -Force:$true -Confirm:$false -ErrorAction SilentlyContinue
                $res = $true
            }
        }

        if (-not $res) {
            Write-Host "No directories left to remove." -ForegroundColor Green
        }

        Invoke-RebootOnDemand -Delay $senDelay -Condition $($senModeR -match "(force)")
    }
    200 {
        Invoke-RebootOnDemand -Delay $senDelay -Condition $($senModeR -match "(auto|force)")
    }
    default {
        Write-Error "Failed to repair SentinelOne installation (${sig})"
        exit 1
    }
}
