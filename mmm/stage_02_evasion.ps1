<#
.SYNOPSIS
  Stage 02 — Defense Evasion / Security Center Status
  Queries real Windows Defender, Firewall, AMSI, Audit Policy state.
#>

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " STAGE 02 - DEFENSE EVASION" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[*] WINDOWS DEFENDER STATUS (Get-MpComputerStatus):" -ForegroundColor Yellow
$mp = Get-MpComputerStatus -ErrorAction SilentlyContinue
if ($mp) {
    Write-Host "    Antivirus Enabled:       $($mp.AntivirusEnabled)"
    Write-Host "    AM Service Enabled:      $($mp.AMServiceEnabled)"
    Write-Host "    Antispyware Enabled:     $($mp.AntispywareEnabled)"
    Write-Host "    Real-time Protection:    $($mp.RealTimeProtectionEnabled)"
    Write-Host "    NIS Enabled:             $($mp.NISEnabled)"
    Write-Host "    IOAV Protection:         $($mp.IoavProtectionEnabled)"
    Write-Host "    Behavior Monitor:        $($mp.BehaviorMonitorEnabled)"
    Write-Host "    Last Quick Scan:         $($mp.QuickScanDateTime)"
    Write-Host "    Last Full Scan:          $($mp.FullScanDateTime)"
    Write-Host "    Signature Version:       $($mp.AntivirusSignatureVersion)"
    Write-Host "    Engine Version:          $($mp.AMEngineVersion)"
} else {
    Write-Host "    [!] Cannot query Defender status."
}

Write-Host ""
Write-Host "[*] DEFENDER PREFERENCES (Get-MpPreference):" -ForegroundColor Yellow
$prefs = Get-MpPreference -ErrorAction SilentlyContinue
if ($prefs) {
    Write-Host "    DisableRealtimeMonitoring: $($prefs.DisableRealtimeMonitoring)"
    Write-Host "    DisableBehaviorMonitoring: $($prefs.DisableBehaviorMonitoring)"
    Write-Host "    DisableIOAVProtection:     $($prefs.DisableIOAVProtection)"
    Write-Host "    DisableBlockAtFirstSeen:   $($prefs.DisableBlockAtFirstSeen)"
    Write-Host "    DisableScriptScanning:     $($prefs.DisableScriptScanning)"
}

Write-Host ""
Write-Host "[*] WINDOWS FIREWALL STATE:" -ForegroundColor Yellow
netsh advfirewall show allprofiles state

Write-Host ""
Write-Host "[*] REGISTERED ANTIVIRUS PRODUCTS (SecurityCenter2):" -ForegroundColor Yellow
Get-WmiObject -Namespace "root\SecurityCenter2" -Class AntiVirusProduct -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "    Product: $($_.displayName)  |  State: $($_.productState)"
}

Write-Host ""
Write-Host "[*] AUDIT POLICY (auditpol /get /category:*):" -ForegroundColor Yellow
auditpol /get /category:* 2>$null | Select-String -SimpleMatch "Success" | Select-Object -First 20

Write-Host ""
Write-Host "[*] AMSI STATUS:" -ForegroundColor Yellow
$amsi = [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
if ($amsi) {
    Write-Host "    AMSI loaded: $true"
    $amsiField = $amsi.GetField('amsiInitFailed', [Reflection.BindingFlags]'NonPublic,Static')
    if ($amsiField) {
        Write-Host "    AMSI initFailed: $($amsiField.GetValue($null))"
    }
} else {
    Write-Host "    AMSI: present"
}

Write-Host ""
Write-Host "[*] EVENTLOG SERVICE STATUS:" -ForegroundColor Yellow
Get-Service EventLog | Format-List Name, Status, StartType

Write-Host ""
Write-Host "[+] STAGE 02 COMPLETE - Security posture captured." -ForegroundColor Green
Start-Sleep -Seconds 3
Exit