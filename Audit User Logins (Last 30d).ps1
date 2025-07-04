<#
    .SYNOPSIS
        Monitoring - Windows - User Session Events
    .DESCRIPTION
        This script will retrieve user session events from the Windows event logs. It will retrieve the following events: Logon, Logoff, Lock, and Unlock. The script will return the events in a table format.
    .PARAMETER Days
        [System.Int32]

        The number of days to retrieve events from. Default is 10 days.
    .PARAMETER NinjaField
        [System.String]

        The NinjaOne custom field to use to store the table.
    .PARAMETER Mode
        [System.String]

        The mode to use when filtering SIDs or usernames. Options are `Include` or `Exclude`. Default is `Include`.
    .PARAMETER SIDs
        [System.Collections.Generic.List[System.String]]

        A list of SIDs to include or exclude from the output. If not specified, all SIDs will be included. If specified, the SIDs specified will be included or excluded depending whether the `Mode` parameter is set to `Include` or `Exclude`.
    .PARAMETER UserNames
        [System.Collections.Generic.List[System.String]]

        A list of user names to include or exclude from the output. If not specified, all user names will be included. If specified, the user names specified will be included or excluded depending whether the `Mode` parameter is set to `Include` or `Exclude`.
    .PARAMETER 
    .NOTES
        2024-05-23: V1.4 - Add support for filtering SIDs or usernames.
        2024-05-22: V1.3 - Add warning if output is over the NinjaOne WYSIWYG field limit of 200,000 characters. Handle errors when parsing SIDs.
        2024-04-15: V1.2 - Fix incorrect event ids for logon and logoff events.
        2024-05-14: V1.1 - Standardise User formatting.
        2024-05-14: V1.0 - Initial version
    .LINK
        Blog post: Not blogged yet.
#>
[CmdletBinding()]
param (
    # The number of days to retrieve events from. Default is 10 days.
    [int]$Days = 30,
    # The NinjaOne custom field to use to store the table.
    [string]$NinjaField = 'UserSessionEvents',
    # The mode to use when filtering SIDs or usernames. Options are `Include` or `Exclude`. Default is `Include`.
    [ValidateSet('Include', 'Exclude')]
    [string]$Mode = 'Include',
    # A list of SIDs to include or exclude from the output. If not specified, all SIDs will be included. If specified, the SIDs specified will be included or excluded depending whether the `Mode` parameter is set to `Include` or `Exclude`.
    [System.Collections.Generic.List[System.String]]$SIDs,
    # A list of user names to include or exclude from the output. If not specified, all user names will be included. If specified, the user names specified will be included or excluded depending whether the `Mode` parameter is set to `Include` or `Exclude`.
    [System.Collections.Generic.List[System.String]]$UserNames
)
# Set parameters from environment variables if they exist
if ($ENV:Days) {
    $Days = [int]::Parse($ENV:Days)
}
if ($ENV:NinjaField) {
    $NinjaField = $ENV:NinjaField
}
if ($ENV:Mode) {
    $Mode = $ENV:Mode
}
if ($ENV:SIDs) {
    [System.Collections.Generic.List[System.String]]$SIDs = $ENV:SIDs -split ','
}
if ($ENV:UserNames) {
    [System.Collections.Generic.List[System.String]]$UserNames = $ENV:UserNames -split ','
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
    $Objects[0].PSObject.Properties.Name | Where-Object { $_ -ne 'RowColour' } | ForEach-Object { [void]$sb.Append("<th>$_</th>") }
    [void]$sb.Append('</tr></thead><tbody>')
    foreach ($obj in $Objects) {
        # Use the RowColour property from the object to set the class for the row
        $rowClass = if ($obj.RowColour) { $obj.RowColour } else { '' }
        [void]$sb.Append("<tr class=`"$rowClass`">")
        # Generate table cells, excluding "RowColour"
        foreach ($propName in $obj.PSObject.Properties.Name | Where-Object { $_ -ne 'RowColour' }) {
            [void]$sb.Append("<td>$($obj.$propName)</td>")
        }
        [void]$sb.Append('</tr>')
    }
    [void]$sb.Append('</tbody></table>')
    $OutputLength = $sb.ToString() | Measure-Object -Character -IgnoreWhiteSpace | Select-Object -ExpandProperty Characters
    if ($OutputLength -gt 200000) {
        Write-Warning ('Output appears to be over the NinjaOne WYSIWYG field limit of 200,000 characters. Actual length was: {0}' -f $OutputLength)
    }
    return $sb.ToString()
}
$Events = [System.Collections.Generic.List[Object]]::new()
$LockUnlockEvents = Get-WinEvent -FilterHashtable @{ 
    LogName = 'Security'
    Id = @(4800, 4801)
    StartTime = (Get-Date).AddDays(-$Days)
} -ErrorAction SilentlyContinue
if ($LockUnlockEvents) {
    $Events.AddRange($LockUnlockEvents)
}
$LoginLogoffEvents = Get-WinEvent -FilterHashtable @{ 
    LogName = 'System'
    Id = @(7001, 7002)
    StartTime = (Get-Date).AddDays(-$Days)
    ProviderName = 'Microsoft-Windows-Winlogon' 
} -ErrorAction SilentlyContinue
if ($LoginLogoffEvents) {
    $Events.AddRange($LoginLogoffEvents)
}
$EventTypeLookup = @{
    7001 = 'Logon'
    7002 = 'Logoff'
    4800 = 'Lock'
    4801 = 'Unlock'
}
$XMLNameSpace = @{'ns' = 'http://schemas.microsoft.com/win/2004/08/events/event' }
$XPathTargetUserSID = "//ns:Data[@Name='TargetUserSid']"
$XPathUserSID = "//ns:Data[@Name='UserSid']"
if ($Events) {
    $Results = ForEach ($Event in $Events) {
        $XML = $Event.ToXML()
        Switch -Regex ($Event.Id) {
            '4...' {
                $SID = (
                    Select-Xml -Content $XML -Namespace $XMLNameSpace -XPath $XPathTargetUserSID
                ).Node.'#text'
                if ($SID) {
                    if ($Mode -eq 'Include') {
                        if ($SIDs -and $SIDs -notcontains $SID) {
                            $Skip = $true
                        }
                    } elseif ($Mode -eq 'Exclude') {
                        if ($SIDs -and $SIDs -contains $SID) {
                            $Skip = $true
                        }
                    }
                    try {
                        $User = [System.Security.Principal.SecurityIdentifier]::new($SID).Translate([System.Security.Principal.NTAccount]).Value
                    } catch {
                        Write-Warning ('Failed to parse SID ({0}) for event {1}.' -f $SID, $Event.Id)
                        $User = $SID
                    }
                    if ($Mode -eq 'Include') {
                        if ($UserNames -and $UserNames -notcontains $User) {
                            $Skip = $true
                        }
                    } elseif ($Mode -eq 'Exclude') {
                        if ($UserNames -and $UserNames -contains $User) {
                            $Skip = $true
                        }
                    }
                } else {
                    Write-Warning ('Failed to parse SID ({0}) for event {1}.' -f $SID, $Event.Id)
                }
                Break            
            }
            '7...' {
                $SID = (
                    Select-Xml -Content $XML -Namespace $XMLNameSpace -XPath $XPathUserSID
                ).Node.'#text'
                if ($SID) {
                    try {
                        if ($Mode -eq 'Include') {
                            if ($SIDs -and $SIDs -notcontains $SID) {
                                $Skip = $true
                            }
                        } elseif ($Mode -eq 'Exclude') {
                            if ($SIDs -and $SIDs -contains $SID) {
                                $Skip = $true
                            }
                        }
                        $User = [System.Security.Principal.SecurityIdentifier]::new($SID).Translate([System.Security.Principal.NTAccount]).Value
                        if ($Mode -eq 'Include') {
                            if ($UserNames -and $UserNames -notcontains $User) {
                                $Skip = $true
                            }
                        } elseif ($Mode -eq 'Exclude') {
                            if ($UserNames -and $UserNames -contains $User) {
                                $Skip = $true
                            }
                        }
                    } catch {
                        Write-Warning ('Failed to parse SID ({0}) for event {1}.' -f $SID, $Event.Id)
                        $User = $SID
                    }
                } else {
                    Write-Warning ('Failed to parse SID ({0}) for event {1}.' -f $SID, $Event.Id)
                }
                Break
            }
        }
        if ($Skip) {
            Continue
        } else {
            $RowColour = switch ($Event.Id) {
                7001 { 'success' }
                7002 { 'danger' }
                4800 { 'warning' }
                4801 { 'other' }
            }
            New-Object -TypeName PSObject -Property @{
                Time = $Event.TimeCreated
                Id = $Event.Id
                Type = $EventTypeLookup[$event.Id]
                User = $User
                RowColour = $RowColour
            }
        }
    }
    if ($Results) {
        $Objects = $Results | Sort-Object Time
        $Table = ConvertTo-ObjectToHtmlTable -Objects $Objects
        $Table | Ninja-Property-Set-Piped $NinjaField
    } else {
        throw 'Failed to process / parse events.'
    }
} else {
    Write-Warning 'No events found.'
}