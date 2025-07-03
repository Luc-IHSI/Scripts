# Script - Manual params 
$pw_length = 15 
$laps_admin = "ihsi_local"
$userIcon = "�"
$passIcon = "�"
$timeIcon = "⏰"

# Get list of current local admins | Note: Not using "Get-LocalGroupMember" as throws error 1789 if domain joined and DC is not in sight
$administrators = net localgroup administrators
$local_admins = $administrators[6..($administrators.Length-3)]

# Generate random password and convert to secure string 
$password_array =  "!@?*0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz".tochararray() 
$password_pt = ( ($password_array | Get-Random -count $pw_length) -join '' )
$password = (ConvertTo-SecureString( $password_pt ) -AsPlainText -Force)
            
# Check if LAPS user with same account name already exists 
$existing_laps_account = Get-LocalUser | Where-Object {$_.Name -eq $laps_admin}

# Create or update LAPS user
if (-not $existing_laps_account) {
    New-LocalUser -Name $laps_admin -Description 'LAPS Local Administrator' -Password $password 
    Write-Host "[Add] New LAPS user created"
} else {
    Set-LocalUser -Name $laps_admin -Password $password
    Write-Host "[Update] Password updated for LAPS account"
}

# Check if LAPS user is a local admin
$is_local_admin = $false
foreach ($admin in $local_admins) {  
    if ($admin -eq $laps_admin) { 
        $is_local_admin = $true
        break
    }  
}

if (-not $is_local_admin) {
    Add-LocalGroupMember -Group "Administrators" -Member $laps_admin 
    Write-Host "[Add] User has been added to the local Administrators group"
} else {
    Write-Host "[Pass] User is already a member of the local Administrators group"
}

# Get timestamp for when password was last set
$timestamp = Get-Date -Format "yyyy/MM/dd HH:mm"

# Unified HTML card output
$htmlContent = @"
<div style='border:1px solid #ccc; border-radius:10px; padding:16px; background-color:#ffffff; color:#333333; font-family:Segoe UI, sans-serif; width:100%; max-width:400px; box-shadow:0 2px 8px rgba(0,0,0,0.1);'>
    <h3 style='margin-top:0; color:#0078D4;'>� LAPS Account Info</h3>
    <div style='margin-bottom:10px;'><strong>$userIcon Username:</strong> $laps_admin</div>
    <div style='margin-bottom:10px;'><strong>$passIcon Password:</strong> $password_pt</div>
    <div style='margin-bottom:10px;'><strong>$timeIcon Password Last Set:</strong> $timestamp</div>
</div>
"@

Ninja-Property-Set lapsUser $htmlContent

# Clear sensitive variables
$password_pt = $null

exit 0
