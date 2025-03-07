# NinjaOne RMM Script Export Tool
# This script exports all scripts from your NinjaOne portal using the API
# Make sure to update the API credentials and base URL before running

#Requires -Version 5.0
#Requires -Modules @{ ModuleName="Microsoft.PowerShell.Utility"; ModuleVersion="3.1.0.0" }

# Configuration - UPDATE THESE VALUES
$apiClientId = "E2siP92sRO0ac4eggy8MDPvkM5E"
$apiClientSecret = "0FLj5L1VwHylrEpQiNwV_MrcPFTfXzhNx3ua1eV-zVc0I5-VwVmUTg"
$ninjaBaseUrl = "https://app.ninjarmm.com" # Or your specific instance URL
$outputFolder = ".\NinjaOne_Scripts_Export" # Where to save the scripts

# Script export options
$exportCustomScriptsOnly = $true # Set to $false if you want to export all scripts including built-in ones
$includeScriptMetadata = $true   # Set to $false if you only want the script files without metadata

# Create output directory if it doesn't exist
if (-not (Test-Path -Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder | Out-Null
    Write-Host "Created output directory: $outputFolder" -ForegroundColor Green
}

# Get categories folder
$categoriesFolder = Join-Path -Path $outputFolder -ChildPath "Categories"
if (-not (Test-Path -Path $categoriesFolder)) {
    New-Item -ItemType Directory -Path $categoriesFolder | Out-Null
}

# Function to get an access token
function Get-NinjaAccessToken {
    $tokenUrl = "$ninjaBaseUrl/ws/oauth/token"
    $body = @{
        grant_type = "client_credentials"
        client_id = $apiClientId
        client_secret = $apiClientSecret
    }
    
    try {
        $response = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $body -ContentType "application/x-www-form-urlencoded"
        return $response.access_token
    }
    catch {
        Write-Error "Failed to get access token: $_"
        exit 1
    }
}

# Function to get all scripts
function Get-NinjaScripts {
    param (
        [string]$AccessToken
    )
    
    $url = "$ninjaBaseUrl/v2/scripts"
    $headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Accept" = "application/json"
    }
    
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
        
        # Filter out native/built-in scripts
        $customScripts = $response | Where-Object {
            (-not $_.isNative) -and 
            (-not $_.isBuiltIn) -and
            (-not $_.isSystem) -and 
            ($_.source -ne "SYSTEM")
        }
        
        Write-Host "Found $($response.count) total scripts, $($customScripts.count) are custom scripts" -ForegroundColor Yellow
        return $customScripts
    }
    catch {
        Write-Error "Failed to get scripts: $_"
        return $null
    }
}

# Function to get script details
function Get-NinjaScriptDetails {
    param (
        [string]$AccessToken,
        [int]$ScriptId
    )
    
    $url = "$ninjaBaseUrl/v2/scripts/$ScriptId"
    $headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Accept" = "application/json"
    }
    
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
        return $response
    }
    catch {
        Write-Error "Failed to get script details for ID $ScriptId: $_"
        return $null
    }
}

# Main execution
Write-Host "Starting NinjaOne RMM Script Export" -ForegroundColor Cyan

# Get the access token
Write-Host "Authenticating to NinjaOne API..." -ForegroundColor Yellow
$accessToken = Get-NinjaAccessToken
if (-not $accessToken) {
    Write-Error "Failed to authenticate. Please check your API credentials."
    exit 1
}
Write-Host "Authentication successful!" -ForegroundColor Green

# Get all script categories 
Write-Host "Fetching script categories..." -ForegroundColor Yellow
$categories = Get-NinjaScriptCategories -AccessToken $accessToken
if ($categories) {
    # Filter out native/system categories if needed
    $customCategories = $categories | Where-Object {
        (-not $_.isNative) -and 
        (-not $_.isSystem) -and 
        ($_.source -ne "SYSTEM")
    }
    
    Write-Host "Found $($categories.count) total categories, $($customCategories.count) are custom categories" -ForegroundColor Green
    $categories = $customCategories
    
    # Save categories metadata
    $categoriesJson = ConvertTo-Json -InputObject $categories -Depth 10
    $categoriesJsonPath = Join-Path -Path $categoriesFolder -ChildPath "categories_metadata.json"
    $categoriesJson | Out-File -FilePath $categoriesJsonPath -Encoding utf8
    
    # Create a lookup table for category names
    $categoryLookup = @{}
    foreach ($category in $categories) {
        $categoryLookup[$category.id] = $category.name
        
        # Create folders for each category
        $categoryFolder = Join-Path -Path $outputFolder -ChildPath $category.name
        if (-not (Test-Path -Path $categoryFolder)) {
            New-Item -ItemType Directory -Path $categoryFolder | Out-Null
        }
    }
}

# Get all scripts
Write-Host "Fetching scripts..." -ForegroundColor Yellow
$scripts = Get-NinjaScripts -AccessToken $accessToken
if ($scripts) {
    Write-Host "Found $($scripts.count) scripts. Exporting details..." -ForegroundColor Green
    
    # Save scripts metadata
    $scriptsJson = ConvertTo-Json -InputObject $scripts -Depth 10
    $scriptsJsonPath = Join-Path -Path $outputFolder -ChildPath "scripts_metadata.json"
    $scriptsJson | Out-File -FilePath $scriptsJsonPath -Encoding utf8
    
    # Export each script
    $counter = 0
    $total = $scripts.count
    
    foreach ($script in $scripts) {
        $counter++
        Write-Progress -Activity "Exporting Scripts" -Status "Processing $counter of $total" -PercentComplete (($counter / $total) * 100)
        
        # Get full script details
        $scriptDetails = Get-NinjaScriptDetails -AccessToken $accessToken -ScriptId $script.id
        
        if ($scriptDetails) {
            # Determine the category folder
            $categoryName = if ($script.categoryId -and $categoryLookup.ContainsKey($script.categoryId)) {
                $categoryLookup[$script.categoryId]
            } else {
                "Uncategorized"
            }
            
            $categoryFolder = Join-Path -Path $outputFolder -ChildPath $categoryName
            if (-not (Test-Path -Path $categoryFolder)) {
                New-Item -ItemType Directory -Path $categoryFolder | Out-Null
            }
            
            # Sanitize script name for file naming
            $safeScriptName = $script.name -replace '[\\/:*?"<>|]', '_'
            
            # Determine file extension based on script type
            $extension = switch ($script.scriptType) {
                "POWERSHELL" { ".ps1" }
                "BATCH" { ".bat" }
                "BASH" { ".sh" }
                default { ".txt" }
            }
            
            # Create the file path
            $scriptFilePath = Join-Path -Path $categoryFolder -ChildPath "$safeScriptName$extension"
            
            # Export script content
            $scriptDetails.script | Out-File -FilePath $scriptFilePath -Encoding utf8
            
            # Export script metadata
            $metadataFilePath = Join-Path -Path $categoryFolder -ChildPath "$safeScriptName.json"
            $scriptMetadata = @{
                id = $script.id
                name = $script.name
                description = $script.description
                scriptType = $script.scriptType
                categoryId = $script.categoryId
                categoryName = $categoryName
                osTypes = $script.osTypes
                createdAt = $script.createdAt
                modifiedAt = $script.modifiedAt
            }
            ConvertTo-Json -InputObject $scriptMetadata -Depth 10 | Out-File -FilePath $metadataFilePath -Encoding utf8
            
            Write-Host "Exported: $safeScriptName$extension" -ForegroundColor Cyan
        }
    }
}

Write-Host "`nScript export complete! All scripts saved to: $outputFolder" -ForegroundColor Green
Write-Host "Total scripts exported: $($scripts.count)" -ForegroundColor Green