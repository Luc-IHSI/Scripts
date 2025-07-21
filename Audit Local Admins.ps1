##This script requires the following script variables!
##CollectAdminUsers - This is a checkbox that controls including local admin accounts in the results.
##CollectAdminGroups - This is a checkbox that controls including local admin groups in the results.
##IncludeAllObjects - This is a checkbox that controls including all returned items of the local account or group such as SID, Object Class, Domain, etc.
##IncludeDisabledAccounts - This is a checkbox that controls whether local admin accounts that are set to disabled are included in the results.
##NamesToExclude - This is a string and allows for entering comma-separated names to be excluded from the returned results.
##CustomDomain - Fill this out for custom domain when looking for AzureAD Hybrid joined/converted users.

##This also requires the following WYSIWYG Custom Field: LocalAdminsAndGroups


function Get-SIDfromUser {
  
    param($User = "")
  
    $objUser = New-Object System.Security.Principal.NTAccount($User) 
    $objSID = $objUser.Translate( [System.Security.Principal.SecurityIdentifier]) 
    return $objSID.Value 
    
}

function ConvertTo-ObjectToHtmlTable {
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[Object]]$Objects
    )

    $sb = New-Object System.Text.StringBuilder

    # Start the HTML table
    [void]$sb.Append('<table><thead><tr>')

    # Add column headers based on the properties of the first object, excluding "RowColour"
    $Objects[0].PSObject.Properties.Name |
    Where-Object { $_ -ne 'RowColour' } |
    ForEach-Object { [void]$sb.Append("<th>$_</th>") }

    [void]$sb.Append('</tr></thead><tbody>')

    foreach ($obj in $Objects) {
        # Use the RowColour property from the object to set the class for the row
        $rowClass = if ($obj.RowColour) { $obj.RowColour } else { "" }

        [void]$sb.Append("<tr class=`"$rowClass`">")
        # Generate table cells, excluding "RowColour"
        foreach ($propName in $obj.PSObject.Properties.Name | Where-Object { $_ -ne 'RowColour' }) {
            [void]$sb.Append("<td>$($obj.$propName)</td>")
        }
        [void]$sb.Append('</tr>')
    }

    [void]$sb.Append('</tbody></table>')

    return $sb.ToString()
}

##This isn't meant to be run on DCs because they do not have local accounts.##
##Test for DC and exit with no alert if DC##
if ((Get-CimInstance -ClassName Win32_OperatingSystem).ProductType -eq 2) {
    Write-Host "Script not designed to run on domain controllers. Exiting."
    Exit 1
}

$AdminGroupName = (Get-CimInstance Win32_Group | Where-Object { $_.SID -eq 'S-1-5-32-544' }).Name
$AdminGroupsAndUsers = Get-CimInstance Win32_Groupuser
$AdminArray = [System.Collections.Generic.List[object]]::new()

if ($env:NamesToExclude) {
    $NamesToExclude = $env:NamesToExclude.Split(',').Trim()
}

if (($env:CollectAdminUsers -eq 'false') -and ($env:CollectAdminGroups -eq 'false')) {
    Write-Host "You must select at least one item, Users or Groups to collect. Exiting."
    Exit 1
}

if ($env:CollectAdminUsers -eq 'true') {

    $AdminUsers = $AdminGroupsAndUsers | 
    Where-Object { $_.groupcomponent -match "$($AdminGroupName)" -and $_.PartComponent -match "Win32_UserAccount" } |
    ForEach-Object {  
        "$($_.PartComponent.Domain)\$($_.PartComponent.Name)"   
    }  

    $AdminUsers = $AdminUsers | Sort-Object -Unique
       
    $Win32UserAccount = Get-CimInstance Win32_UserAccount
    $DomainMatch = 'AzureAD'
    if ($env:CustomDomain){
        $DomainMatch = "AzureAD|$($env:CustomDomain)"
    }
    foreach ($User in $AdminUsers) {
        if ($User -match "$($DomainMatch)") {
            $Array = New-Object PSObject -Property @{
                Name            = $User
                Disabled        = ''
                Domain          = "$($User.Split('\')[0].Trim())"
                LocalAccount    = 'True'
                Lockout         = 'N/A'
                PasswordExpires = 'N/A'
                SID             = Get-SIDfromUser $User
                ObjectClass     = 'UserAccount'
            }
            if ($Array.Name -ne "" -and $null -ne $Array.Name) {
                $AdminArray.Add($Array)
            }
        }
        else {
            $UserInfos = @($Win32UserAccount | Where-Object { $_.Caption -eq $User } |
                Select-Object Name, LocalAccount, PasswordExpires, SID, Disabled, Lockout, @{Name = "Class"; E = { $_.CimClass -replace "root/cimv2:Win32_", "" } }, Domain)
            foreach ($UserInfo in $UserInfos) {
                $Array = New-Object PSObject -Property @{
                    Name            = $UserInfo.Name
                    Disabled        = $UserInfo.Disabled
                    Domain          = $UserInfo.Domain
                    LocalAccount    = $UserInfo.LocalAccount
                    Lockout         = $UserInfo.Lockout
                    PasswordExpires = $UserInfo.PasswordExpires
                    SID             = $UserInfo.SID
                    ObjectClass     = $UserInfo.Class
                }
                if ($Array.Name -ne "" -and $null -ne $Array.Name) {
                    $AdminArray.Add($Array)
                }
            }
        }
    }
}

if ($env:CollectAdminGroups -eq 'true') {

    $AdminGroups = $AdminGroupsAndUsers | 
    Where-Object { $_.groupcomponent -match "($($AdminGroupName))" -and $_.PartComponent -match "Win32_Group" } |
    ForEach-Object {  
        "$($_.PartComponent.Name)"     
    } 

    $AdminGroups = $AdminGroups | Sort-Object -Unique

    $Win32Groups = Get-CimInstance Win32_Group

    foreach ($Group in $AdminGroups) {
        $GroupInfos = @($Win32Groups | Where-Object { $_.Name -eq $Group } | 
            Select-Object Name, Domain, SID, @{Name = "Class"; E = { $_.CimClass -replace "root/cimv2:Win32_", "" } })
    
        foreach ($GroupInfo in $GroupInfos) {
            $Array = New-Object PSObject -Property @{
                Name            = $GroupInfo.Name
                Disabled        = $false
                Domain          = $GroupInfo.Domain
                LocalAccount    = [bool]$(if ($null -eq $GroupInfo.LocalAccount) { $false } else { $true })
                Lockout         = $false
                PasswordExpires = $false
                SID             = $GroupInfo.SID
                ObjectClass     = $GroupInfo.Class
            }
            if ($Array.Name -ne "" -and $null -ne $Array.Name) {
                $AdminArray.Add($Array)
            }
        }
    }
}

if ($NamesToExclude) {
    $AdminArray = $AdminArray | Where-Object { $_.Name -notin $NamesToExclude }
}

if ($env:IncludeDisabledAccounts -ne 'true') {
    $AdminArray = $AdminArray | Where-Object { !($_.Disabled) }
}

if (($null -eq $AdminArray) -or ($AdminArray.Count -eq 0)) {
    Write-Host "No admin accounts found."
    Exit 0
}

if ($env:IncludeAllObjects -eq 'true') {
    $AdminHTML = ConvertTo-ObjectToHtmlTable $AdminArray
    $AdminHTML | Ninja-Property-Set-Piped LocalAdminsandGroups
    $AdminArray
}
else {
    $AllAdmins = $AdminArray | Select-Object Name
    $AdminHTML = ConvertTo-ObjectToHtmlTable $AllAdmins
    $AdminHTML | Ninja-Property-Set-Piped LocalAdminsandGroups
    $AllAdmins
}