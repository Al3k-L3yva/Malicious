Write-Host "============================================" -ForegroundColor Cyan
Write-Host " DEFENSE: CREDENTIAL DUMPING DETECTION" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# -- 1. DETECT SUSPICIOUS FILES IN TEMP --
Write-Host "[*] SCANNING TEMP DIRECTORIES FOR DUMPED FILES" -ForegroundColor Yellow
$suspiciousPaths = @(
    "$env:USERPROFILE\AppData\Local\Temp",
    "$env:TEMP",
    "$env:TMP",
    "C:\Users\Public"
)

$suspiciousExtensions = @("*.hive", "*.dmp", "*SAM*", "*SYSTEM*", "*SECURITY*", "*lsass*", "*login_data*", "*logins.json*", "*key4.db*")
$foundThreats = $false

foreach ($path in $suspiciousPaths) {
    if (Test-Path $path) {
        foreach ($ext in $suspiciousExtensions) {
            $files = Get-ChildItem -Path $path -Filter $ext -File -ErrorAction SilentlyContinue | 
                Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-2) }
            
            if ($files) {
                $foundThreats = $true
                Write-Host "  [!] SUSPICIOUS FILES FOUND in $path" -ForegroundColor Red
                $files | ForEach-Object {
                    $sizeKB = [math]::Round($_.Length / 1KB, 1)
                    Write-Host "      $($_.Name) ($sizeKB KB) - Modified: $($_.LastWriteTime)" -ForegroundColor Yellow
                }
            }
        }
    }
}

if (-not $foundThreats) {
    Write-Host "  [+] No suspicious dump files found in temp directories" -ForegroundColor Green
}
Write-Host ""

# -- 2. DETECT REGISTRY HIVE DUMP ATTEMPTS --
Write-Host "[*] CHECKING FOR REGISTRY HIVE DUMP EVENTS" -ForegroundColor Yellow
$regDumpEvents = Get-WinEvent -FilterHashtable @{
    LogName   = 'Security'
    ID        = 4656, 4663  # Handle requested, Object access
    StartTime = (Get-Date).AddHours(-2)
} -ErrorAction SilentlyContinue | Where-Object {
    $_.Message -match 'SAM|SYSTEM|SECURITY' -and $_.Message -match 'reg\.exe|reg save'
}

if ($regDumpEvents) {
    Write-Host "  [!] REGISTRY HIVE ACCESS DETECTED" -ForegroundColor Red
    $regDumpEvents | Select-Object -First 5 | ForEach-Object {
        Write-Host "      Time: $($_.TimeCreated)" -ForegroundColor Yellow
        Write-Host "      User: $($_.Properties[1].Value)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [+] No registry hive dump events found" -ForegroundColor Green
}
Write-Host ""

# -- 3. DETECT LSASS DUMP ATTEMPTS --
Write-Host "[*] CHECKING FOR LSASS MINIDUMP ACTIVITY" -ForegroundColor Yellow
$lsassDumpEvents = Get-WinEvent -FilterHashtable @{
    LogName   = 'Microsoft-Windows-Sysmon/Operational'
    ID        = 1, 10  # Process creation, Process access
    StartTime = (Get-Date).AddHours(-2)
} -ErrorAction SilentlyContinue | Where-Object {
    $_.Message -match 'lsass|comsvcs\.dll|MiniDump|procdump'
}

if ($lsassDumpEvents) {
    Write-Host "  [!] LSASS DUMP ATTEMPT DETECTED" -ForegroundColor Red
    $lsassDumpEvents | Select-Object -First 5 | ForEach-Object {
        Write-Host "      Event ID: $($_.Id) | Time: $($_.TimeCreated)" -ForegroundColor Yellow
        $msg = $_.Message.Substring(0, [Math]::Min(150, $_.Message.Length))
        Write-Host "      Details: $msg..." -ForegroundColor Gray
    }
} else {
    Write-Host "  [+] No LSASS dump activity detected" -ForegroundColor Green
}

# Check for active rundll32 processes with comsvcs.dll
$rundll32Processes = Get-Process -Name rundll32 -ErrorAction SilentlyContinue | Where-Object {
    $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)").CommandLine
    $cmdLine -match 'comsvcs\.dll|MiniDump'
}

if ($rundll32Processes) {
    Write-Host "  [!] ACTIVE LSASS DUMP PROCESS DETECTED" -ForegroundColor Red
    $rundll32Processes | ForEach-Object {
        Write-Host "      PID: $($_.Id) | Started: $($_.StartTime)" -ForegroundColor Yellow
    }
}
Write-Host ""

# -- 4. DETECT BROWSER CREDENTIAL THEFT --
Write-Host "[*] CHECKING FOR BROWSER CREDENTIAL ACCESS" -ForegroundColor Yellow
$browserPaths = @(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"
)

$browserTheftDetected = $false
foreach ($browserPath in $browserPaths) {
    if (Test-Path $browserPath) {
        $originalFile = Get-Item $browserPath
        $recentCopies = Get-ChildItem -Path "$env:TEMP", "$env:USERPROFILE\AppData\Local\Temp" -Filter "*login*" -File -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-2) -and $_.Length -eq $originalFile.Length }
        
        if ($recentCopies) {
            $browserTheftDetected = $true
            Write-Host "  [!] BROWSER CREDENTIAL FILE COPIED" -ForegroundColor Red
            $recentCopies | ForEach-Object {
                Write-Host "      Original: $browserPath" -ForegroundColor Yellow
                Write-Host "      Copy: $($_.FullName) ($([math]::Round($_.Length / 1KB, 1)) KB)" -ForegroundColor Yellow
            }
        }
    }
}

# Check Firefox
$ffProfiles = Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles\*.default*" -Directory -ErrorAction SilentlyContinue
foreach ($prof in $ffProfiles) {
    $loginsFile = "$($prof.FullName)\logins.json"
    if (Test-Path $loginsFile) {
        $recentCopies = Get-ChildItem "$env:TEMP" -Filter "*logins.json*" -File -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-2) }
        if ($recentCopies) {
            $browserTheftDetected = $true
            Write-Host "  [!] FIREFOX CREDENTIALS COPIED" -ForegroundColor Red
        }
    }
}

if (-not $browserTheftDetected) {
    Write-Host "  [+] No browser credential theft detected" -ForegroundColor Green
}
Write-Host ""

# -- 5. DETECT WIFI PASSWORD EXTRACTION --
Write-Host "[*] CHECKING FOR WIFI PASSWORD ENUMERATION" -ForegroundColor Yellow
$wifiEvents = Get-WinEvent -FilterHashtable @{
    LogName   = 'Microsoft-Windows-PowerShell/Operational'
    ID        = 4104  # Script block logging
    StartTime = (Get-Date).AddHours(-2)
} -ErrorAction SilentlyContinue | Where-Object {
    $_.Message -match 'netsh wlan show profile.*key=clear'
}

if ($wifiEvents) {
    Write-Host "  [!] WIFI PASSWORD EXTRACTION DETECTED" -ForegroundColor Red
    $wifiEvents | Select-Object -First 3 | ForEach-Object {
        Write-Host "      Time: $($_.TimeCreated)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [+] No WiFi password extraction detected" -ForegroundColor Green
}
Write-Host ""

# -- 6. DETECT CREDENTIAL MANAGER ACCESS --
Write-Host "[*] CHECKING FOR CREDENTIAL MANAGER ENUMERATION" -ForegroundColor Yellow
$credMgrEvents = Get-WinEvent -FilterHashtable @{
    LogName   = 'Microsoft-Windows-PowerShell/Operational'
    ID        = 4104
    StartTime = (Get-Date).AddHours(-2)
} -ErrorAction SilentlyContinue | Where-Object {
    $_.Message -match 'cmdkey /list|cmdkey\s*/list'
}

if ($credMgrEvents) {
    Write-Host "  [!] CREDENTIAL MANAGER ENUMERATION DETECTED" -ForegroundColor Red
    $credMgrEvents | Select-Object -First 3 | ForEach-Object {
        Write-Host "      Time: $($_.TimeCreated)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [+] No credential manager enumeration detected" -ForegroundColor Green
}
Write-Host ""

# -- 7. VERIFY INTEGRITY OF CRITICAL FILES --
Write-Host "[*] VERIFYING INTEGRITY OF CRITICAL SYSTEM FILES" -ForegroundColor Yellow
$criticalFiles = @(
    "C:\Windows\System32\config\SAM",
    "C:\Windows\System32\config\SYSTEM",
    "C:\Windows\System32\config\SECURITY"
)

foreach ($file in $criticalFiles) {
    if (Test-Path $file) {
        $fileInfo = Get-Item $file
        $lastAccess = $fileInfo.LastAccessTime
        $lastWrite = $fileInfo.LastWriteTime
        
        if ($lastAccess -gt (Get-Date).AddHours(-2) -and $lastAccess -ne $lastWrite) {
            Write-Host "  [!] CRITICAL FILE ACCESSED: $file" -ForegroundColor Red
            Write-Host "      Last Access: $lastAccess" -ForegroundColor Yellow
        } else {
            Write-Host "  [+] $file - No recent unauthorized access" -ForegroundColor Green
        }
    }
}
Write-Host ""

# -- SUMMARY --
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " DETECTION SUMMARY" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

if ($foundThreats -or $regDumpEvents -or $lsassDumpEvents -or $browserTheftDetected -or $wifiEvents -or $credMgrEvents) {
    Write-Host "  [!] CREDENTIAL DUMPING ACTIVITY DETECTED" -ForegroundColor Red
    Write-Host "      Immediate actions recommended:" -ForegroundColor Yellow
    Write-Host "      1. Isolate affected system from network" -ForegroundColor White
    Write-Host "      2. Reset all credentials (local admin, domain, browser)" -ForegroundColor White
    Write-Host "      3. Collect forensic evidence before cleanup" -ForegroundColor White
    Write-Host "      4. Review access logs for lateral movement" -ForegroundColor White
} else {
    Write-Host "  [+] NO CREDENTIAL DUMPING ACTIVITY DETECTED" -ForegroundColor Green
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host " DEFENSE SCAN COMPLETE" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Start-Sleep -Seconds 3
