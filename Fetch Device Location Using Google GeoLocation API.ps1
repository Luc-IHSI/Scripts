#Requires -Version 5.1

<#
.SYNOPSIS
    Updates Custom Fields with the location of a device based on the Google GeoLocation API.
.DESCRIPTION
    Updates Custom Fields with the location of a device based on the Google GeoLocation API.

    The CustomFieldName parameter can be used to specify which custom field to save the Latitude and Longitude coordinates to.
    The AddressCustomFieldName parameter can be used to specify which custom field to save the address to.

    This script requires a custom field to save location data in NinjaRMM.
    The default for CustomFieldName is "Location".
    The default for AddressCustomFieldName is "Address".
    You can use any text custom field that you wish.
.EXAMPLE
    -GoogleApiKey "<GeoLocation API key here>"
    Saves the Latitude and Longitude coordinates to the custom field named Location.
.EXAMPLE
    -GoogleApiKey "<GeoLocation API key here>" -CustomFieldName "Location" -AddressCustomFieldName "Address"
    Saves the Latitude and Longitude coordinates to the custom field named Location as well as the address to Address.
.INPUTS
    None
.OUTPUTS
    None
.NOTES
    Minimum OS Architecture Supported: Windows 10
    Release Notes:
    Updated to work with either Parameters or Script Variables
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
    [String]
    $GoogleApiKey,
    [Parameter()]
    [String]
    $CustomFieldName = "Location",
    [Parameter()]
    [String]
    $AddressCustomFieldName = "Address"
)

begin {
    function Test-StringEmpty {
        param([string]$Text)
        # Returns true if string is empty, null, or whitespace
        process { [string]::IsNullOrEmpty($Text) -or [string]::IsNullOrWhiteSpace($Text) }
    }
    function Get-NearestCity {
        param (
            [double]$lat,
            [double]$lon,
            [string]$GoogleApi
        )
        try {
            $Response = Invoke-RestMethod -Uri "http://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lon&key=$GoogleApi"
        }
        catch {
            throw $Error[0]
        }
        return $Response.results[0].formatted_address
    }
    function Get-WifiNetwork {
        end {
            try {
                netsh.exe wlan sh net mode=bssid | ForEach-Object -Process {
                    if ($_ -match '^SSID (d+) : (.*)$') {
                        $current = @{}
                        $networks += $current
                        $current.Index = $matches[1].trim()
                        $current.SSID = $matches[2].trim()
                    }
                    else {
                        if ($_ -match '^s+(.*)s+:s+(.*)s*$') {
                            $current[$matches[1].trim()] = $matches[2].trim()
                        }
                    }
                } -Begin { $networks = @() } -End { $networks | ForEach-Object { New-Object -TypeName "PSObject" -Property $_ } }    
            }
            catch {
                # return nothing
            }
        }
    }

    # Check if Script Variables are being used
    if (-not $(Test-StringEmpty -Text $env:GoogleApiKey)) {
        $GoogleApiKey = $env:GoogleApiKey
    }
    if (-not $(Test-StringEmpty -Text $env:CustomFieldName)) {
        $CustomFieldName = $env:CustomFieldName
    }
    if (-not $(Test-StringEmpty -Text $env:AddressCustomFieldName)) {
        $AddressCustomFieldName = $env:AddressCustomFieldName
    }
    # Check if api key is set, error if not set
    if ($(Test-StringEmpty -Text $GoogleApiKey)) {
        # Both Parameter and Script Variable are empty
        # Can not combine Parameter "[Parameter(Mandatory)]" and Script Variable Required
        Write-Error "GoogleApiKey is required."
        exit 1
    }

    # Use the system's new line
    $NewLine = $([System.Environment]::NewLine)

    # Build URL with API key
    $Url = "https://www.googleapis.com/geolocation/v1/geolocate?key=$GoogleApiKey"
}
process {
    # Get WIFI network data nearby
    $WiFiData = Get-WifiNetwork |
        Select-Object @{name = 'age'; expression = { 0 } },
        @{name = 'macAddress'; expression = { $_.'BSSID 1' } },
        @{name = 'channel'; expression = { $_.Channel } },
        @{name = 'signalStrength'; expression = { (($_.Signal -replace "%") / 2) - 100 } }

    # Check if we got any number access points
    $Body = if ($WiFiData -and $WiFiData.Count -gt 0) {
        @{
            considerIp       = $true
            wifiAccessPoints = $WiFiData
        } | ConvertTo-Json
    }
    else {
        @{
            considerIp = $true
        } | ConvertTo-Json
    }

    # Get our lat,lng position
    try {
        $Response = Invoke-RestMethod -Method Post -Uri $Url -Body $Body -ContentType "application/json" -ErrorVariable Err
    }
    catch {
        Write-Error $_
        exit 1
    }

    # Save the relevant results to variable that have shorter names
    $Lat = $Response.location.lat
    $Lon = $Response.location.lng

    try {
        # Save Latitude, Longitude to the custom field from the CustomFieldName parameter
        Ninja-Property-Set -Name $CustomFieldName -Value "$Lat,$Lon"
    }
    catch {
        Write-Error "Failed to save to CustomFieldName($CustomFieldName)"
        exit 1
    }

    if ( $(Test-StringEmpty -Text $AddressCustomFieldName) -and $(Test-StringEmpty -Text $env:AddressCustomFieldName)) {
        # Both Parameter and Variable are empty
        Write-Output "$($NewLine)Location: $Lat,$Lon"
    }
    else {
        if ($(Test-StringEmpty -Text $AddressCustomFieldName)) {
            # Parameter was not used
            $AddressCustomFieldName = $env:AddressCustomFieldName
        }

        try {
            # Get City from Google API's
            # Google API: https://developers.google.com/maps/documentation/geocoding/requests-reverse-geocoding
            $Address = Get-NearestCity -lat $Lat -lon $Lon -GoogleApi $GoogleApiKey
        }
        catch {
            Write-Error "Failed to save to get nearest city."
            exit 1
        }

        try {
            # Save Lat and Lon to custom field
            Ninja-Property-Set -Name $AddressCustomFieldName -Value "$Address"
            Write-Output "$($NewLine)Location: $Address`: $Lat,$Lon"
        }
        catch {
            Write-Error "Failed to save to AddressCustomFieldName($AddressCustomFieldName)"
            exit 1
        }
    }
    exit 0
}
end {
    $ScriptVariables = @(
        [PSCustomObject]@{
            name           = "GoogleApiKey"
            calculatedName = "GoogleApiKey"
            required       = $true
            defaultValue   = $null
            valueType      = "TEXT"
            valueList      = $null
            description    = ""
        }
        [PSCustomObject]@{
            name           = "CustomFieldName"
            calculatedName = "CustomFieldName"
            required       = $false
            defaultValue   = [PSCustomObject]@{
                type  = "TEXT"
                value = "Location"
            }
            valueType      = "TEXT"
            valueList      = $null
            description    = ""
        }
    )
}