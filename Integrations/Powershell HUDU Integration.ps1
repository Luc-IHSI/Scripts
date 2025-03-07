# Log in to Microsoft Office 365
Install-Module -Name Az -AllowClobber -Scope CurrentUser
Connect-AzAccount

# Navigate to Azure Active Directory and create a new app registration
$app = New-AzADApplication -DisplayName "HUDU"

# Ensure the app registration was created successfully
if ($null -eq $app) {
    Write-Error "Failed to create app registration."
    exit
}

# Output the $app object to inspect its properties
Write-Output "App Registration Details: $($app | ConvertTo-Json -Depth 3)"

# Copy down the Application (client) ID and Directory (tenant) ID
$clientId = $app.AppId
$tenantId = (Get-AzTenant).Id

# Check if $app.Id is not empty
if ([string]::IsNullOrEmpty($app.Id)) {
    Write-Error "App Id is empty."
    exit
}

# Set API permissions
$graphApp = Get-AzADServicePrincipal -DisplayName "Microsoft Graph"
if ($null -eq $graphApp) {
    Write-Error "Microsoft Graph service principal not found."
    exit
}
$graphAppId = $graphApp.Id

# Output the Microsoft Graph App ID
Write-Output "Microsoft Graph App ID: $graphAppId"

# Get a valid access token for Microsoft Graph
$secureToken = (Get-AzAccessToken -ResourceUrl 'https://graph.microsoft.com' -AsSecureString).Token
$token = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken))

# Get the roles for the Microsoft Graph service principal
$roles = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($graphApp.Id)/appRoles" -Headers @{
    "Authorization" = "Bearer $token"
}

# Find the role IDs for the required permissions
$directoryReadAllRoleId = ($roles.value | Where-Object { $_.value -eq "Directory.Read.All" }).id
$reportsReadAllRoleId = ($roles.value | Where-Object { $_.value -eq "Reports.Read.All" }).id
$userReadAllRoleId = ($roles.value | Where-Object { $_.value -eq "User.Read.All" }).id

# Assign the roles to the application using Microsoft Graph API
$sp = New-AzADServicePrincipal -ApplicationId $app.AppId
$consentUri = "https://graph.microsoft.com/v1.0/servicePrincipals/$($sp.Id)/appRoleAssignments"

# Grant consent for each role
foreach ($roleId in @($directoryReadAllRoleId, $reportsReadAllRoleId, $userReadAllRoleId)) {
    $consentBody = @{
        "principalId" = $sp.Id
        "resourceId"  = $graphAppId
        "appRoleId"   = $roleId
    } | ConvertTo-Json

    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type"  = "application/json"
    }

    Invoke-RestMethod -Uri $consentUri -Method POST -Headers $headers -Body $consentBody
}

# Create a client secret for the app registration
# $clientSecretValue = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((New-Guid).Guid))
$clientSecret = New-Object -TypeName Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.MicrosoftGraphPasswordCredential
$clientSecret.EndDateTime = (Get-Date).AddYears(2)
# $clientSecret.SecretText = $clientSecretValue

# Add the client secret to the app registration
New-AzADAppCredential -ObjectId $app.Id -PasswordCredential $clientSecret
# Output the Application (client) ID, Directory (tenant) ID
Write-Output "Client ID: $clientId"
Write-Output "Tenant ID: $tenantId"

Read-Host -Prompt "Press Enter to exit"