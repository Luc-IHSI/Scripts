# Run the System File Checker
Write-Output "Running SFC..."
$sfcOutput = & {
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo.FileName = "sfc.exe"
    $process.StartInfo.Arguments = "/scannow"
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.Start()
    $output = $process.StandardOutput.ReadToEnd()
    $process.WaitForExit()
    $output
}

# Check the SFC output for errors
if ($sfcOutput -contains "W i n d o w s   R e s o u r c e   P r o t e c t i o n   d i d   n o t   f i n d   a n y   i n t e g r i t y   v i o l a t i o n s") {
    $sfcResult = "No errors found"
    $sfcIcon = "✅"
    Write-Host "Windows Resource Protection did not find any integrity violations"
} else {
    $sfcResult = "Errors found, Action required"
    $sfcIcon = "⛔"
}

# Create initial HTML content for SFC
$htmlContent = @"
    <table border='0'>
        <tr>
            <th style='width: 250px;'>$sfcIcon SFC</th>
            <td>$sfcResult</td>
        </tr>
    </table>
"@

# Output initial HTML content to a file
Ninja-Property-Set systemhealthcheck $htmlContent

# Run DISM to repair Windows image
Write-Output "Running DISM..."
$dismCheckHealth = dism /Online /Cleanup-Image /CheckHealth
$dismScanHealth = dism /Online /Cleanup-Image /ScanHealth
$dismRestoreHealth = dism /Online /Cleanup-Image /RestoreHealth

# Check the result of DISM
$dismResult = $?
if ($sfcResult -eq "No errors found") {
    $dismResultText = "No errors found"
    $dismIcon = "✅"
} elseif ($sfcResult -eq "Errors found, Action required") {
    $dismResultText = "Bugs found and fixed"
    $dismIcon = "⚠️"
} else {
    $dismResultText = "Errors found, Manual action required"
    $dismIcon = "⛔"
}

$lastTwoLines = $dismRestoreHealth -split "`n" | Select-Object -Last 2

# Output the last 2 lines
Write-Host $lastTwoLines

# Append DISM result to HTML content
$htmlContent += @"
    <table border='0'>
        <tr>
            <th style='width: 250px;'>$dismIcon DISM</th>
            <td>$dismResultText</td>
        </tr>
    </table>
"@

# Output final HTML content to a file
Ninja-Property-Set systemhealthcheck $htmlContent

# Run Check Disk on all disks
Write-Output "Running Check Disk on all disks..."

# Get all disks
$disks = Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType=3"

# Initialize a list to store results for all drives
$chkdskResults = @()

# Loop through each disk and run chkdsk
foreach ($disk in $disks) {
    $driveLetter = $disk.DeviceID
    Write-Output "Running chkdsk on $driveLetter"
    
    $chkdskOutput = & {
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo.FileName = "chkdsk.exe"
        $process.StartInfo.Arguments = "$driveLetter /scan"
        $process.StartInfo.RedirectStandardOutput = $true
        $process.StartInfo.UseShellExecute = $false
        $process.StartInfo.CreateNoWindow = $true
        $process.Start()
        $output = $process.StandardOutput.ReadToEnd()
        $process.WaitForExit()
        $output
    }

    # Check the chkdsk output for errors
    if ($chkdskOutput -contains "Windows has scanned the file system and found no problems") {
        $chkdskResult = "No errors found on $driveLetter"
        $chkdskIcon = "✅"
        Write-Host "No errors found on $driveLetter"
    } else {
        $chkdskResult = "Errors found $driveLetter, Action required"
        $chkdskIcon = "⛔"
    }

    # Add the result to the list
    $chkdskResults += "$chkdskResult"
}

# Join all results into a single string
$chkdskResultsText = $chkdskResults -join "<br>"

# Append CHKDSK results to HTML content
$htmlContent += @"
    <table border='0'>
        <tr>
            <th style='width: 250px;'>$chkdskIcon CHKDSK</th>
            <td>$chkdskResultsText</td>
        </tr>
    </table>
"@

# Output final HTML content to a file
Ninja-Property-Set systemhealthcheck $htmlContent