#Requires -RunAsAdministrator

# Configure NTFS Permissions for the MDT Build Lab deployment share
$DeploymentShareNTFS = "M:\MDTBuildLab"
icacls $DeploymentShareNTFS /grant '"Administrator":(OI)(CI)(RX)'
icacls $DeploymentShareNTFS /grant '"Users":(OI)(CI)(RX)'
icacls $DeploymentShareNTFS /grant '"Administrators":(OI)(CI)(F)'
icacls $DeploymentShareNTFS /grant '"SYSTEM":(OI)(CI)(F)'
icacls "$DeploymentShareNTFS\Captures" /grant '"Administrator":(OI)(CI)(M)'

# Configure Sharing Permissions for the MDT Build Lab deployment share
$DeploymentShare = "MDTBuildLab$"
Grant-SmbShareAccess -Name $DeploymentShare -AccountName "EVERYONE" -AccessRight Change -Force
Revoke-SmbShareAccess -Name $DeploymentShare -AccountName "CREATOR OWNER" -Force