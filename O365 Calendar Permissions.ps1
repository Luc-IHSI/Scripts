# Check PowerShell execution policy
$currentPolicy = Get-ExecutionPolicy
Write-Host "Current execution policy: $currentPolicy" -ForegroundColor Yellow

# Set execution policy if needed
if ($currentPolicy -eq "Restricted") {
    Write-Host "Setting execution policy to RemoteSigned for current user..." -ForegroundColor Yellow
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    }
    catch {
        Write-Host "Failed to set execution policy. You may need to run PowerShell as Administrator." -ForegroundColor Red
        exit
    }
}

# Check if Exchange Online module is installed, install if not
if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Write-Host "Exchange Online Management module not found. Installing..." -ForegroundColor Yellow
    try {
        Install-Module -Name ExchangeOnlineManagement -Force -AllowClobber -Scope CurrentUser
        Write-Host "Module installed successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to install module: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
        exit
    }
}

# Import the Exchange Online module
Write-Host "Importing Exchange Online Management module..." -ForegroundColor Green
try {
    Import-Module ExchangeOnlineManagement -Force
    Write-Host "Module imported successfully." -ForegroundColor Green
}
catch {
    Write-Host "Failed to import module: $($_.Exception.Message)" -ForegroundColor Red
    exit
}

# Verify the module is loaded and cmdlets are available
if (-not (Get-Command Connect-ExchangeOnline -ErrorAction SilentlyContinue)) {
    Write-Host "Connect-ExchangeOnline cmdlet not found. Please check module installation." -ForegroundColor Red
    exit
}

$admin = Read-Host "Please enter the admin user email address"
$msg     = 'Do you want add additional permissions?'
$options = '&Yes', '&No'
$default = 1  # 0=Yes, 1=No

Connect-ExchangeOnline -UserPrincipalName $admin -ShowProgress $true

do {
    $UserOne = Read-Host "Please enter the email of the user whose calendar needs shared."
    $UserTwo = Read-Host "Please enter the email of the user who needs access to the calendar."
    
    Write-Host "Please select the level of access needed:"
    Write-Host "1. Owner"
    Write-Host "2. PublishingEditor"
    Write-Host "3. Editor"
    Write-Host "4. PublishingAuthor"
    Write-Host "5. Author"
    Write-Host "6. NonEditingAuthor"
    Write-Host "7. Reviewer"
    Write-Host "8. Contributor"
    Write-Host "9. AvailabilityOnly"
    Write-Host "10. LimitedDetails"
    Write-Host "11. None"
    
    $choice = Read-Host "Enter the number corresponding to the desired access level"
    
    switch ($choice) {
        1 { $AccessLevel = "Owner" }
        2 { $AccessLevel = "PublishingEditor" }
        3 { $AccessLevel = "Editor" }
        4 { $AccessLevel = "PublishingAuthor" }
        5 { $AccessLevel = "Author" }
        6 { $AccessLevel = "NonEditingAuthor" }
        7 { $AccessLevel = "Reviewer" }
        8 { $AccessLevel = "Contributor" }
        9 { $AccessLevel = "AvailabilityOnly" }
        10 { $AccessLevel = "LimitedDetails" }
        11 { $AccessLevel = "None" }
        default {
            Write-Host "Invalid choice. Setting access level to None."
            $AccessLevel = "None"
        }
    }
    
    Add-MailboxFolderPermission -Identity $UserOne":\calendar" -User $UserTwo -AccessRights $AccessLevel
    
    $response = $Host.UI.PromptForChoice($title, $msg, $options, $default)
} while ($response -eq '0')