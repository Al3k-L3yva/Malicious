Write-Host "============================================" -ForegroundColor Cyan
Write-Host " DEFENSE: ENUMERATION & PRIVESC DETECTION" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# -- 1. DETECT POWERSHELL ENUMERATION COMMANDS --
Write-Host "[*] SCANNING FOR ENUMERATION COMMANDS IN POWERSHELL LOGS" -ForegroundColor Yellow
$enumPatterns = @(
    'whoami /all',
    'Get-LocalGroup',
    'Get-LocalGroupMember',
    'Get-WmiObject Win32_Service',
    'Get-ScheduledTask',
    'AlwaysInstallElevated',
    'Get-ItemProperty.*Uninstall'
)

$psEvents = Get-WinEvent -FilterHashtable @{
    LogName   = 'Microsoft-Windows-PowerShell/Operational'
    ID        = 4104
    StartTime = (Get-Date).AddHours(-2)
} -ErrorAction SilentlyContinue

$suspiciousCommands = @()
if ($psEvents) {
    foreach ($event in $psEvents) {
        $message = $event.Message
        foreach ($pattern in $enumPatterns) {
            if ($message -match $pattern) {
                $suspiciousCommands += [PSCustomObject]@{
                    Time = $event.TimeCreated
                    Pattern = $pattern
                    Command = $message.Substring(0, [Math]::Min(200, $message.Length))
                }
                break
            }
        }
    }
}

if ($suspiciousCommands) {
    Write-Host "  [!] ENUMERATION COMMANDS DETECTED" -ForegroundColor Red
    $suspiciousCommands | Select-Object -First 10 | ForEach-Object {
        Write-Host "      Time: $($_.Time)" -ForegroundColor Yellow
        Write-Host "      Pattern: $($_.Pattern)" -ForegroundColor Yellow
        Write-Host "      Command: $($_.Command)..." -ForegroundColor Gray
        Write-Host ""
    }
} else {
    Write-Host "  [+] No enumeration commands detected in PowerShell logs" -ForegroundColor Green
}
Write-Host ""

# -- 2. DETECT REGISTRY ACCESS FOR PRIVESC VECTORS --
Write-Host "[*] CHECKING FOR REGISTRY ENUMERATION" -ForegroundColor Yellow
$regAccessEvents = Get-WinEvent -FilterHashtable @{
    LogName   = 'Security'
    ID        = 4656, 4657, 4663
    StartTime = (Get-Date).AddHours(-2)
} -ErrorAction SilentlyContinue | Where-Object {
    $_.Message -match 'AlwaysInstallElevated|Installer|Uninstall'
}

if ($regAccessEvents) {
    Write-Host "  [!] SUSPICIOUS REGISTRY ACCESS DETECTED" -ForegroundColor Red
    $regAccessEvents | Select-Object -First 5 | ForEach-Object {
        Write-Host "      Time: $($_.TimeCreated)" -ForegroundColor Yellow
        Write-Host "      Event ID: $($_.Id)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [+] No suspicious registry access detected" -ForegroundColor Green
}
Write-Host ""

# -- 3. DETECT SERVICE ENUMERATION --
Write-Host "[*] CHECKING FOR SERVICE ENUMERATION ACTIVITY" -ForegroundColor Yellow
$serviceEnumEvents = Get-WinEvent -FilterHashtable @{
    LogName   = 'Microsoft-Windows-PowerShell/Operational'
    ID        = 4104
    StartTime = (Get-Date).AddHours(-2)
} -ErrorAction SilentlyContinue | Where-Object {
    $_.Message -match 'Win32_Service|Get-Service|sc.exe query'
}

if ($serviceEnumEvents) {
    Write-Host "  [!] SERVICE ENUMERATION DETECTED" -ForegroundColor Red
    $serviceEnumEvents | Select-Object -First 5 | ForEach-Object {
        Write-Host "      Time: $($_.TimeCreated)" -ForegroundColor Yellow
        $msg = $_.Message.Substring(0, [Math]::Min(150, $_.Message.Length))
        Write-Host "      Command: $msg..." -ForegroundColor Gray
    }
} else {
    Write-Host "  [+] No service enumeration detected" -ForegroundColor Green
}

# Check for unquoted service path exploitation attempts
$unquotedPaths = Get-WmiObject Win32_Service | Where-Object {
    $_.PathName -match '^[^"\\].*\s.*\.exe' -and $_.PathName -notlike "*\windows\*"
}

if ($unquotedPaths) {
    Write-Host "  [!] UNQUOTED SERVICE PATHS VULNERABLE" -ForegroundColor Yellow
    $unquotedPaths | Select-Object -First 5 | ForEach-Object {
        Write-Host "      $($_.Name): $($_.PathName)" -ForegroundColor Gray
    }
}
Write-Host ""

# -- 4. DETECT WRITABLE PATH TESTING --
Write-Host "[*] CHECKING FOR WRITABLE PATH TESTING" -ForegroundColor Yellow
$testFiles = Get-ChildItem -Path "$env:TEMP", "$env:USERPROFILE\AppData\Local\Temp", "C:\Windows\Temp", "$env:PUBLIC" -Filter ".writetest_*.txt" -File -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-2) }

if ($testFiles) {
    Write-Host "  [!] WRITABLE PATH TESTING DETECTED" -ForegroundColor Red
    $testFiles | ForEach-Object {
        Write-Host "      File: $($_.FullName)" -ForegroundColor Yellow
        Write-Host "      Created: $($_.LastWriteTime)" -ForegroundColor Gray
    }
} else {
    Write-Host "  [+] No writable path testing detected" -ForegroundColor Green
}
Write-Host ""

# -- 5. DETECT SCHEDULED TASK ENUMERATION --
Write-Host "[*] CHECKING FOR SCHEDULED TASK ENUMERATION" -ForegroundColor Yellow
$taskEnumEvents = Get-WinEvent -FilterHashtable @{
    LogName   = 'Microsoft-Windows-PowerShell/Operational'
    ID        = 4104
    StartTime = (Get-Date).AddHours(-2)
} -ErrorAction SilentlyContinue | Where-Object {
    $_.Message -match 'Get-ScheduledTask|schtasks /query'
}

if ($taskEnumEvents) {
    Write-Host "  [!] SCHEDULED TASK ENUMERATION DETECTED" -ForegroundColor Red
    $taskEnumEvents | Select-Object -First 5 | ForEach-Object {
        Write-Host "      Time: $($_.TimeCreated)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [+] No scheduled task enumeration detected" -ForegroundColor Green
}

# Check for recently created suspicious tasks
$newTasks = Get-ScheduledTask | Where-Object {
    $_.TaskPath -notlike "*\Microsoft\*" -and $_.Date -gt (Get-Date).AddHours(-2)
} -ErrorAction SilentlyContinue

if ($newTasks) {
    Write-Host "  [!] NEW NON-MICROSOFT TASKS CREATED" -ForegroundColor Yellow
    $newTasks | ForEach-Object {
        Write-Host "      Task: $($_.TaskName) | State: $($_.State)" -ForegroundColor Gray
    }
}
Write-Host ""

# -- 6. DETECT PROCESSES PERFORMING ENUMERATION --
Write-Host "[*] CHECKING FOR ACTIVE ENUMERATION PROCESSES" -ForegroundColor Yellow
$suspiciousProcesses = Get-Process -Name powershell, pwsh, cmd -ErrorAction SilentlyContinue | 
    Where-Object { $_.StartTime -gt (Get-Date).AddMinutes(-30) }

$enumRunning = $false
foreach ($proc in $suspiciousProcesses) {
    try {
        $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId=$($proc.Id)").CommandLine
        if ($cmdLine -match 'whoami|Get-LocalGroup|Win32_Service|Get-ScheduledTask|AlwaysInstallElevated') {
            Write-Host "  [!] ACTIVE ENUMERATION PROCESS" -ForegroundColor Red
            Write-Host "      PID: $($proc.Id) | Process: $($proc.ProcessName)" -ForegroundColor Yellow
            Write-Host "      Started: $($proc.StartTime)" -ForegroundColor Yellow
            Write-Host "      Command: $cmdLine" -ForegroundColor Gray
            Write-Host ""
            $enumRunning = $true
        }
    } catch { continue }
}

if (-not $enumRunning) {
    Write-Host "  [+] No active enumeration processes detected" -ForegroundColor Green
}
Write-Host ""

# -- 7. VERIFY ALWAYSINSTALLELEVATED STATUS --
Write-Host "[*] VERIFYING ALWAYSINSTALLELEVATED CONFIGURATION" -ForegroundColor Yellow
$hkcu = Get-ItemProperty "HKCU:\Software\Policies\Microsoft\Windows\Installer" -Name AlwaysInstallElevated -ErrorAction SilentlyContinue
$hklm = Get-ItemProperty "HKLM:\Software\Policies\Microsoft\Windows\Installer" -Name AlwaysInstallElevated -ErrorAction SilentlyContinue

if ($hkcu -and $hklm -and $hkcu.AlwaysInstallElevated -eq 1 -and $hklm.AlwaysInstallElevated -eq 1) {
    Write-Host "  [!] ALWAYSINSTALLELEVATED IS ENABLED (PRIVESC VECTOR)" -ForegroundColor Red
    Write-Host "      This allows non-admin users to install MSI packages with SYSTEM privileges" -ForegroundColor Yellow
} else {
    Write-Host "  [+] AlwaysInstallElevated is properly disabled" -ForegroundColor Green
}
Write-Host ""

# -- 8. DETECT SOFTWARE ENUMERATION --
Write-Host "[*] CHECKING FOR SOFTWARE ENUMERATION" -ForegroundColor Yellow
$softwareEnumEvents = Get-WinEvent -FilterHashtable @{
    LogName   = 'Microsoft-Windows-PowerShell/Operational'
    ID        = 4104
    StartTime = (Get-Date).AddHours(-2)
} -ErrorAction SilentlyContinue | Where-Object {
    $_.Message -match 'Get-ItemProperty.*Uninstall|Get-WmiObject.*Win32_Product'
}

if ($softwareEnumEvents) {
    Write-Host "  [!] SOFTWARE ENUMERATION DETECTED" -ForegroundColor Red
    $softwareEnumEvents | Select-Object -First 5 | ForEach-Object {
        Write-Host "      Time: $($_.TimeCreated)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [+] No software enumeration detected" -ForegroundColor Green
}
Write-Host ""

# -- SUMMARY --
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " DETECTION SUMMARY" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

$totalThreats = $suspiciousCommands.Count + $regAccessEvents.Count + $serviceEnumEvents.Count + $testFiles.Count + $taskEnumEvents.Count + $softwareEnumEvents.Count

if ($totalThreats -gt 0 -or $enumRunning -or $unquotedPaths -or ($hkcu -and $hklm)) {
    Write-Host "  [!] ENUMERATION & PRIVESC PREPARATION DETECTED" -ForegroundColor Red
    Write-Host "      Indicators found: $totalThreats" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "      Recommended actions:" -ForegroundColor Cyan
    Write-Host "      1. Identify the user/process performing enumeration" -ForegroundColor White
    Write-Host "      2. Check if this is authorized penetration testing" -ForegroundColor White
    Write-Host "      3. If unauthorized, isolate the system immediately" -ForegroundColor White
    Write-Host "      4. Review unquoted service paths and fix them" -ForegroundColor White
    Write-Host "      5. Disable AlwaysInstallElevated if enabled" -ForegroundColor White
    Write-Host "      6. Monitor for privilege escalation attempts" -ForegroundColor White
} else {
    Write-Host "  [+] NO ENUMERATION OR PRIVESC PREPARATION DETECTED" -ForegroundColor Green
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host " DEFENSE SCAN COMPLETE" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Start-Sleep -Seconds 3
