#Requires -Version 5.1

<#
.SYNOPSIS
    Checks if the hosts file was modified from last run.
.DESCRIPTION
    Checks if the hosts file was modified from last run.
    On first run this will not produce an error, but will create a cache file for later comparison.
.EXAMPLE
    No parameters needed.
.OUTPUTS
    None
.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
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
    # Path and file of the hosts file
    [string]
    $HostsPath = "C:WindowsSystem32driversetchosts",
    # Path and file where the cache file will be saved for comparison
    [string]
    $CachePath = "C:ProgramDataNinjaRMMAgentscriptingTest-HostsFile.clixml"
)

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

    # Check if hosts file exists
    if ($(Test-Path -Path $HostsPath)) {
        # Get content and create hash of hosts file
        $HostsContent = Get-Content -Path $HostsPath
        $HostsHash = Get-FileHash -Path $HostsPath -Algorithm SHA256

        $Current = [PSCustomObject]@{
            Content = $HostsContent
            Hash    = $HostsHash
        }

        # Check if this is first run or not
        if ($(Test-Path -Path $CachePath)) {
            # Compare last content and hash
            $Cache = Import-Clixml -Path $CachePath
            $ContentDifference = Compare-Object -ReferenceObject $Cache.Content -DifferenceObject $Current.Content -CaseSensitive
            $HashDifference = $Cache.Hash -like $Current.Hash
            $Current | Export-Clixml -Path $CachePath -Force -Confirm:$false
            if (-not $HashDifference) {
                Write-Host "Hosts file has changed since last run!"
                Write-Host ""
                $ContentDifference | ForEach-Object {
                    if ($_.SideIndicator -like '=>') {
                        Write-Host "Added: $($_.InputObject)"
                    }
                    elseif ($_.SideIndicator -like '<=') {
                        Write-Host "Removed: $($_.InputObject)"
                    }
                }
                exit 1
            }
        }
        else {
            Write-Host "First run, saving comparison cache file."
            $Current | Export-Clixml -Path $CachePath -Force -Confirm:$false
        }
    }
    else {
        Write-Error "Hosts file is missing!"
        exit 1
    }
    exit 0
}
end {}