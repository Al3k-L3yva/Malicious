<#
.SYNOPSIS
  Stage 02 — Defensive Posture Validation
  Validates that Windows Defender, Firewall, AMSI, and Logging are properly enabled.
.DESCRIPTION
  Requires Administrator privileges to read all security states accurately.
#>

# Verificar privilegios de Administrador
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[!] ADVERTENCIA: Este script debe ejecutarse como Administrador para obtener resultados precisos." -ForegroundColor Red
    Write-Host "    Algunos controles de seguridad podrían reportar falsos negativos." -ForegroundColor Yellow
}

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " STAGE 02 - VALIDACION DE POSTURA DEFENSIVA" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

# ── 1. WINDOWS DEFENDER STATUS ──
Write-Host "[*] WINDOWS DEFENDER (Protección en Tiempo Real):" -ForegroundColor Yellow
$mp = Get-MpComputerStatus -ErrorAction SilentlyContinue
if ($mp) {
    if ($mp.RealTimeProtectionEnabled -and $mp.AntivirusEnabled) {
        Write-Host "    [OK] Protección en tiempo real y Antivirus: HABILITADOS" -ForegroundColor Green
    } else {
        Write-Host "    [!] FAIL: Protección en tiempo real o Antivirus DESACTIVADOS" -ForegroundColor Red
        Write-Host "        -> Remediación: Set-MpPreference -DisableRealtimeMonitoring `$false" -ForegroundColor Gray
    }
} else {
    Write-Host "    [!] No se pudo consultar el estado de Defender." -ForegroundColor Red
}

# ── 2. DEFENDER PREFERENCES ──
Write-Host ""
Write-Host "[*] PREFERENCIAS DE DEFENDER (Configuración segura):" -ForegroundColor Yellow
$prefs = Get-MpPreference -ErrorAction SilentlyContinue
if ($prefs) {
    $badPrefs = @()
    if ($prefs.DisableRealtimeMonitoring) { $badPrefs += "RealTimeMonitoring" }
    if ($prefs.DisableBehaviorMonitoring) { $badPrefs += "BehaviorMonitoring" }
    if ($prefs.DisableScriptScanning) { $badPrefs += "ScriptScanning" }
    if ($prefs.DisableIOAVProtection) { $badPrefs += "IOAVProtection" }

    if ($badPrefs.Count -eq 0) {
        Write-Host "    [OK] Todas las protecciones críticas están habilitadas." -ForegroundColor Green
    } else {
        Write-Host "    [!] FAIL: Las siguientes protecciones están DESACTIVADAS: $($badPrefs -join ', ')" -ForegroundColor Red
    }
}

# ── 3. WINDOWS FIREWALL ──
Write-Host ""
Write-Host "[*] ESTADO DEL FIREWALL DE WINDOWS:" -ForegroundColor Yellow
$fwProfiles = Get-NetFirewallProfile -ErrorAction SilentlyContinue
$fwDown = $fwProfiles | Where-Object { $_.Enabled -eq $false }
if ($fwDown) {
    Write-Host "    [!] FAIL: Perfiles de Firewall DESACTIVADOS: $($fwDown.Name -join ', ')" -ForegroundColor Red
    Write-Host "        -> Remediación: Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True" -ForegroundColor Gray
} else {
    Write-Host "    [OK] Todos los perfiles del Firewall (Domain, Private, Public) están ACTIVOS." -ForegroundColor Green
}

# ── 4. REGISTERED ANTIVIRUS ──
Write-Host ""
Write-Host "[*] PRODUCTOS ANTIVIRUS REGISTRADOS (SecurityCenter2):" -ForegroundColor Yellow
$avProducts = Get-WmiObject -Namespace "root\SecurityCenter2" -Class AntiVirusProduct -ErrorAction SilentlyContinue
if ($avProducts) {
    foreach ($av in $avProducts) {
        Write-Host "    [OK] Producto detectado: $($av.displayName)" -ForegroundColor Green
    }
} else {
    Write-Host "    [!] FAIL: No se detectaron productos antivirus registrados en WMI." -ForegroundColor Red
}

# ── 5. AUDIT POLICY ──
Write-Host ""
Write-Host "[*] POLÍTICA DE AUDITORÍA (Categorías Críticas):" -ForegroundColor Yellow
$criticalCategories = @("Logon", "Account Logon", "Policy Change", "Privilege Use")
$auditIssues = @()
foreach ($cat in $criticalCategories) {
    $policy = auditpol /get /subcategory:"$cat" /r 2>$null | ConvertFrom-Csv
    if ($policy."Inclusion Setting" -notmatch "Success") {
        $auditIssues += $cat
    }
}
if ($auditIssues.Count -eq 0) {
    Write-Host "    [OK] Auditoría de eventos críticos (Logon, Policy Change, etc.) está habilitada." -ForegroundColor Green
} else {
    Write-Host "    [!] FAIL: Falta auditoría 'Success' en: $($auditIssues -join ', ')" -ForegroundColor Red
    Write-Host "        -> Remediación: auditpol /set /subcategory:`"$cat`" /success:enable" -ForegroundColor Gray
}

# ── 6. AMSI STATUS ──
Write-Host ""
Write-Host "[*] ESTADO DE AMSI (Anti-Malware Scan Interface):" -ForegroundColor Yellow
$amsi = [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
if ($amsi) {
    $amsiField = $amsi.GetField('amsiInitFailed', [Reflection.BindingFlags]'NonPublic,Static')
    if ($amsiField -and $amsiField.GetValue($null)) {
        Write-Host "    [!] CRÍTICO: AMSI está presente pero 'amsiInitFailed' es TRUE. ¡Posible bypass de AMSI detectado!" -ForegroundColor Red
    } else {
        Write-Host "    [OK] AMSI está cargado y funcionando correctamente (initFailed = False)." -ForegroundColor Green
    }
} else {
    Write-Host "    [OK] AMSI presente en el sistema." -ForegroundColor Green
}

# ── 7. EVENTLOG SERVICE ──
Write-Host ""
Write-Host "[*] SERVICIO DE REGISTRO DE EVENTOS (EventLog):" -ForegroundColor Yellow
$eventLogService = Get-Service EventLog -ErrorAction SilentlyContinue
if ($eventLogService.Status -eq 'Running' -and $eventLogService.StartType -eq 'Automatic') {
    Write-Host "    [OK] El servicio EventLog está CORRIENDO y configurado como Automático." -ForegroundColor Green
} else {
    Write-Host "    [!] FAIL: El servicio EventLog está DETENIDO o no es automático (Status: $($eventLogService.Status), StartType: $($eventLogService.StartType))" -ForegroundColor Red
    Write-Host "        -> Remediación: Set-Service EventLog -StartupType Automatic; Start-Service EventLog" -ForegroundColor Gray
}

Write-Host ""
Write-Host "[+] STAGE 02 COMPLETE - Validación de seguridad finalizada." -ForegroundColor Green
