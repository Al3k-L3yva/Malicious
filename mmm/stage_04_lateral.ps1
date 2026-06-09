<#
.SYNOPSIS
    Stage 04 — Local Enumeration & Privilege Escalation Prep (Real Actions)
.DESCRIPTION
    Enumerates local privileges, services, scheduled tasks, writable paths,
    unquoted service paths, AlwaysInstallElevated, and other local
    privilege escalation vectors.
#>

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " STAGE 04: LATERAL MOVEMENT & PRIVESC PREP" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ── Current User & Privileges ──
Write-Host "[*] CURRENT USER & PRIVILEGES" -ForegroundColor Yellow
whoami /all 2>$null
Write-Host ""

# ── Local Groups ──
Write-Host "[*] LOCAL SECURITY GROUPS" -ForegroundColor Yellow
Get-LocalGroup | ForEach-Object {
    $name = $_.Name
    $members = (Get-LocalGroupMember -Group $name -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }) -join ", "
    Write-Host "  $name → $members"
}
Write-Host ""

# ── Services ──
Write-Host "[*] SERVICES (NON-MICROSOFT, RUNNING)" -ForegroundColor Yellow
Get-WmiObject Win32_Service | Where-Object {
    $_.StartMode -eq "Auto" -and $_.State -eq "Running" -and
    $_.PathName -notlike "*\windows\*" -and $_.PathName -notlike "*\System32\*"
} | ForEach-Object {
    Write-Host "  $($_.Name)  →  $($_.PathName)" -ForegroundColor Gray
}
Write-Host ""

# ── Unquoted Service Paths ──
Write-Host "[*] UNQUOTED SERVICE PATH CHECK" -ForegroundColor Yellow
Get-WmiObject Win32_Service | Where-Object {
    $_.PathName -match '^[^"\\].*\s.*\.exe' -and $_.PathName -notlike "*\windows\*"
} | ForEach-Object {
    Write-Host "  [!] $($_.Name): $($_.PathName)" -ForegroundColor Red
}
Write-Host ""

# ── AlwaysInstallElevated ──
Write-Host "[*] ALWAYS INSTALL ELEVATED CHECK" -ForegroundColor Yellow
$hkcu = Get-ItemProperty "HKCU:\Software\Policies\Microsoft\Windows\Installer" -Name AlwaysInstallElevated -ErrorAction SilentlyContinue
$hklm = Get-ItemProperty "HKLM:\Software\Policies\Microsoft\Windows\Installer" -Name AlwaysInstallElevated -ErrorAction SilentlyContinue
if ($hkcu -and $hklm) {
    Write-Host "  [!] AlwaysInstallElevated is ENABLED" -ForegroundColor Red
} else {
    Write-Host "  [-] AlwaysInstallElevated not enabled" -ForegroundColor Gray
}
Write-Host ""

# ── Scheduled Tasks (Non-Microsoft) ──
Write-Host "[*] SCHEDULED TASKS (NON-MICROSOFT)" -ForegroundColor Yellow
try {
    $tasks = Get-ScheduledTask 2>$null | Where-Object { $_.TaskPath -notlike "*\Microsoft\*" }
    foreach ($task in $tasks) {
        $actions = @($task.Actions) -join "; "
        Write-Host "  $($task.TaskName) [$($task.State)]"
        foreach ($action in $task.Actions) {
            Write-Host "      → $($action.Execute) $($action.Arguments)" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "  (Scheduled task enumeration requires admin for some tasks)"
}
Write-Host ""

# ── Writable Paths ──
Write-Host "[*] CHECKING WRITABLE PATHS" -ForegroundColor Yellow
$paths = @(
    "$env:TEMP",
    "$env:USERPROFILE\AppData\Local\Temp",
    "C:\Windows\Temp",
    "$env:PUBLIC",
    "$env:USERPROFILE\Documents"
)
foreach ($path in $paths) {
    if (Test-Path $path) {
        try {
            $testFile = "$path\.writetest_$(Get-Random).txt"
            [System.IO.File]::WriteAllText($testFile, "test")
            Remove-Item $testFile -Force -ErrorAction SilentlyContinue
            Write-Host "  [+] Writable: $path" -ForegroundColor Green
        } catch {
            Write-Host "  [-] Not writable: $path" -ForegroundColor Red
        }
    }
}
Write-Host ""

# ── Installed Software ──
Write-Host "[*] INSTALLED APPLICATIONS" -ForegroundColor Yellow
Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | 
    Where-Object { $_.DisplayName } |
    Sort-Object DisplayName |
    Select-Object DisplayName, DisplayVersion -First 30 |
    ForEach-Object {
        Write-Host "  $($_.DisplayName) [$($_.DisplayVersion)]"
    }
Write-Host ""

Write-Host "============================================" -ForegroundColor Green
Write-Host " STAGE 04 COMPLETE" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green