<#
.SYNOPSIS
    Find large OST files in the user's folder or recursively under C:.
.DESCRIPTION
    Find large OST files in the user's folder or recursively under C:.
.PARAMETER MinSize
    The minimum file size. This expects the file size to be in gigabytes.
.PARAMETER AllFolders
    Will search all folders under C:.
.EXAMPLE
     -MinSize 50
    Search for OST files larger than 50GB in each user's Outlook folder.
.EXAMPLE
     -AllFolders -MinSize 50
    Search for OST files larger than 50GB under C: recursively.
.OUTPUTS
    String[]
.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Exit code 1: If at least 1 OST was found larger than MinSize
    Exit code 0: If no OST's where found larger than MinSize
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
    [double]
    $MinSize = 50,
    [switch]
    $AllFolders
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
    $script:Found = $false

    if ($AllFolders) {
        $FoundFiles = Get-ChildItem C: -Filter *.ost -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.Length / ($MinSize * 1GB) -gt 1 }
        $FoundFiles | Select-Object FullName, Length | ForEach-Object {
            $Name = $_.FullName
            $Size = $_.Length
            Write-Host "$Name $Size bytes"
        }
        # If you wish to automatically remove the file(s) uncomment the line below. Do note that this is permanent! Make backups!
        # $FoundFiles | Remove-Item -Force -Confirm:$false
        if ($FoundFiles) {
            $script:Found = $true
        }
    }
    else {
        $UsersFolder = "C:Users"
        $Outlook = "AppDataLocalMicrosoftOutlook"
        Get-ChildItem -Path $UsersFolder | ForEach-Object {
            $User = $_
            $Folder = "$UsersFolder$User$Outlook"
            if ($(Test-Path -Path $Folder)) {
                $FoundFiles = Get-ChildItem $Folder -Filter *.ost | Where-Object { $_.Length / ($MinSize * 1GB) -gt 1 }
                $FoundFiles | Select-Object FullName, Length | ForEach-Object {
                    $Name = $_.FullName
                    $Size = $_.Length
                    Write-Host "$Name $Size bytes"
                }
                # If you wish to automatically remove the file(s) uncomment the line below. Do note that this is permanent! Make backups!
                # $FoundFiles | Remove-Item -Force -Confirm:$false
                if ($FoundFiles) {
                    Write-Verbose "Found"
                    $script:Found = $true
                }
            }
        }
    }

    if ($script:Found) {
        exit 1
    }
    exit 0
}
end {}