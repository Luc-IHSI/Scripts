#Requires -Version 5.1

<#
.SYNOPSIS
    Updates a Custom Field with the total size of all User Profiles.
    If the Max parameter is specified then it will return an exit code of 1
     for any profile being over that Max threshold in GB.
.DESCRIPTION
    Updates a Custom Field with the total size of all User Profiles.
    If the Max parameter is specified then it will return an exit code of 1
     for any profile being over that Max threshold in GB.
.EXAMPLE
     -Max 60
    Returns and exit code of 1 if any profile is over 60GB
.EXAMPLE
     -CustomField "Something"
    Specifies the name of the custom field to update.
.EXAMPLE
    No Parameter needed.
    Uses the default custom field name: TotalUsersProfileSize
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
    [Parameter()]
    [Alias("MaxSize", "Size", "ms", "m", "s")]
    [Double]
    $Max,
    [Parameter()]
    [Alias("Custom", "Field", "cf", "c", "f")]
    [String]
    $CustomField = "TotalUsersProfileSize"
)

begin {
    function Test-IsElevated {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object System.Security.Principal.WindowsPrincipal($id)
        $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    function Format-FileSize {
        param($Length)
        switch ($Length) {
            { $_ / 1TB -gt 1 } { "$([Math]::Round(($_ / 1TB),2)) TB"; break }
            { $_ / 1GB -gt 1 } { "$([Math]::Round(($_ / 1GB),2)) GB"; break }
            { $_ / 1MB -gt 1 } { "$([Math]::Round(($_ / 1MB),2)) MB"; break }
            { $_ / 1KB -gt 1 } { "$([Math]::Round(($_ / 1KB),2)) KB"; break }
            Default { "$_ Bytes" }
        }
    }
}
process {
    if (-not (Test-IsElevated)) {
        Write-Error -Message "Access Denied. Please run with Administrator privileges."
        exit 1
    }

    $Profiles = Get-ChildItem -Path "C:Users"
    $ProfileSizes = $Profiles | ForEach-Object {
        [PSCustomObject]@{
            Name   = $_.BaseName
            Length = Get-ChildItem -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue | Select-Object -Property Sum -ExpandProperty Sum
        }
    }
    $Largest = $ProfileSizes | Sort-Object -Property Length -Descending | Select-Object -First 1

    $Size = $ProfileSizes | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue | Select-Object -Property Sum -ExpandProperty Sum

    $FormattedSize = Format-FileSize -Length $Size

    $AllProfiles = $ProfileSizes | Sort-Object -Property Length -Descending | ForEach-Object {
        $FormattedSizeUser = Format-FileSize -Length $_.Length
        "$($_.Name) $($FormattedSizeUser)"
    }

    Write-Host "All Profiles - $FormattedSize, $($AllProfiles -join ', ')"

    Ninja-Property-Set -Name $CustomField -Value "$AllProfiles"

    if ($Max -and $Max -gt 0) {
        if ($Largest.Length -gt $Max * 1GB) {
            Write-Host "Found profile over the max size of $Max GB."
            Write-Host "$($Largest.Name) profile is $($Largest.Length / 1GB) GB"
            exit 1
        }
    }
    exit 0
}
end {}