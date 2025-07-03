#Requires -Version 5.1

<#
.SYNOPSIS
    Clears Print Queue for all printers
.DESCRIPTION
    Clears Print Queue for all printers.
    This script will stop the printer spooler service, clear all print jobs, and start the printer spooler service.
    If some print jobs are not cleared, then a reboot might be needed before running this script again.
.EXAMPLE
    No parameters needed
.OUTPUTS
    String
.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Release Notes:
    Initial Release
    (c) 2023 NinjaOne
    By using this script, you indicate your acceptance of the following legal terms as well as our Terms of Use at https://www.ninjaone.com/terms-of-use.
    Ownership Rights: NinjaOne owns and will continue to own all right, title, and interest in and to the script (including the copyright). NinjaOne is giving you a limited license to use the script in accordance with these legal terms. 
    Use Limitation: You may only use the script for your legitimate personal or internal business purposes, and you may not share the script with another party. 
    Republication Prohibition: Under no circumstances are you permitted to re-publish the script in any script library or website belonging to or under the control of any other software provider. 
    Warranty Disclaimer: The script is provided “as is” and “as available”, without warranty of any kind. NinjaOne makes no promise or guarantee that the script will be free from defects or that it will meet your specific needs or expectations. 
    Assumption of Risk: Your use of the script is at your own risk. You acknowledge that there are certain inherent risks in using the script, and you understand and assume each of those risks. 
    Waiver and Release: You will not hold NinjaOne responsible for any adverse or unintended consequences resulting from your use of the script, and you waive any legal or equitable rights or remedies you may have against NinjaOne relating to your use of the script. 
    EULA: If you are a NinjaOne customer, your use of the script is subject to the End User License Agreement applicable to you (EULA).
.COMPONENT
    Printer
#>

[CmdletBinding()]
param ()

begin {
    function Test-IsElevated {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object System.Security.Principal.WindowsPrincipal($id)
        $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }
}

process {
    if (-not (Test-IsElevated)) {
        Write-Error -Message "Access Denied. Please run with Administrator privileges."
        exit 1
    }
    Write-Host "Stopping print spooler service"
    $StopProcess = Start-Process -FilePath "C:WINDOWSsystem32net.exe" -ArgumentList "stop", "spooler" -Wait -NoNewWindow -PassThru
    # Exit Code 2 usually means the service is already stopped
    if ($StopProcess.ExitCode -eq 0 -or $StopProcess.ExitCode -eq 2) {
        Write-Host "Stopped print spooler service"
        # Sleep just in case the spooler service is taking some time to stop
        Start-Sleep -Seconds 10
        Write-Host "Clearing all print queues"
        Remove-Item -Path "$env:SystemRootSystem32spoolPRINTERS*" -Force -ErrorAction SilentlyContinue
        Write-Host "Cleared all print queues"

        Write-Host "Starting print spooler service"
        $StartProcess = Start-Process -FilePath "C:WINDOWSsystem32net.exe" -ArgumentList "start", "spooler" -Wait -NoNewWindow -PassThru
        if ($StartProcess.ExitCode -eq 0) {
            Write-Host "Started print spooler service"
        }
        else {
            Write-Host "Could not start Print Spooler service. net start spooler returned exit code of $($StartProcess.ExitCode)"
            exit 1
        }
    }
    else {
        Write-Host "Could not stop Print Spooler service. net stop spooler returned exit code of $($StopProcess.ExitCode)"
        exit 1
    }
    exit 0
}

end {}