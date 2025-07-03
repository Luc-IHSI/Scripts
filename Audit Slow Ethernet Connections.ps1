#Requires -Version 5.1

<#
.SYNOPSIS
    Identify if any wired ethernet connections that are running slower than 1 Gbps.
.DESCRIPTION
    Identify if any wired ethernet connections that are running slower than 1 Gbps.
    This can highlight devices that are connected to old hubs/switches or have bad cabling.
.OUTPUTS
    None
.NOTES
    Minimum supported OS: Windows 10, Server 2016
    Release Notes:
    Initial release
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
param ()

process {
    $NetworkAdapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {
        $_.Virtual -eq $false -and # Filter out any adapter that are Virtual, like VPN's
        $_.Status -like "Up" -and # Filter out any disconnected adapters
        ($_.PhysicalMediaType -like "*802.3*" -or $_.NdisPhysicalMedium -eq 14) -and # Filter out adapters like Wifi
        $_.LinkSpeed -notlike "*Gbps" # Filter out the 1, 2.5, and 10 Gbps network adapters
    }
    $NetworkAdapters | Select-Object Name, InterfaceDescription, Status, LinkSpeed
    if ($NetworkAdapters) {
        exit 1
    }
}