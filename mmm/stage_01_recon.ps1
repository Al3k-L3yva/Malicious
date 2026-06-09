<#
.SYNOPSIS
    Stage 01 — System & Network Reconnaissance (Real Actions)
.DESCRIPTION
    Gathers real system information, user accounts, network configuration,
    running processes, open ports, and startup programs. All output is live.
#>

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " STAGE 01: SYSTEM & NETWORK RECONNAISSANCE" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ── System Information ──
Write-Host "[*] SYSTEM INFORMATION" -ForegroundColor Yellow
Write-Host ""

$cs = Get-WmiObject Win32_ComputerSystem
Write-Host "  Hostname:        $($cs.Name)"
Write-Host "  Manufacturer:    $($cs.Manufacturer)"
Write-Host "  Model:           $($cs.Model)"
Write-Host "  Total RAM:       $([math]::Round($cs.TotalPhysicalMemory / 1GB, 2)) GB"
Write-Host "  Domain/Workgroup: $($cs.Domain)"

$os = Get-WmiObject Win32_OperatingSystem
Write-Host "  OS:              $($os.Caption)"
Write-Host "  Version:         $($os.Version)"

# Corrección de formato de fecha WMI
$bootTime = [System.Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime)
Write-Host "  Last Boot:       $($bootTime)"
$uptime = (Get-Date) - $bootTime
Write-Host "  Uptime:          $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"

$bios = Get-WmiObject Win32_BIOS
Write-Host "  BIOS Serial:     $($bios.SerialNumber)"
Write-Host ""

# ── Local Users ──
Write-Host "[*] LOCAL USER ACCOUNTS" -ForegroundColor Yellow
Write-Host ""
Get-LocalUser | ForEach-Object {
    $enabled = if ($_.Enabled) { "Enabled" } else { "Disabled" }
    Write-Host "  $($_.Name) ($enabled) - $($_.FullName)"
}
Write-Host ""

# ── Administrators Group (Language Independent via SID) ──
Write-Host "[*] ADMINISTRATORS GROUP MEMBERS" -ForegroundColor Yellow
Write-Host ""
# SID S-1-5-32-544 es el grupo nativo de administradores sin importar el idioma
$adminGroup = Get-LocalGroup | Where-Object { $_.SID -eq "S-1-5-32-544" }
if ($adminGroup) {
    Get-LocalGroupMember -Group $adminGroup.Name | ForEach-Object {
        Write-Host "  $($_.Name)  [$($_.ObjectClass)]"
    }
}
Write-Host ""

# ── Network Configuration ──
Write-Host "[*] NETWORK CONFIGURATION" -ForegroundColor Yellow
Write-Host ""
$adapters = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
foreach ($adapter in $adapters) {
    Write-Host "  Adapter: $($adapter.Description)"
    Write-Host "    IP:      $($adapter.IPAddress -join ', ')"
    Write-Host "    Subnet:  $($adapter.IPSubnet -join ', ')"
    Write-Host "    Gateway: $($adapter.DefaultIPGateway -join ', ')"
    Write-Host "    DNS:     $($adapter.DNSServerSearchOrder -join ', ')"
    Write-Host "    MAC:     $($adapter.MACAddress)"
    Write-Host ""
}

# ── Active Network Connections ──
Write-Host "[*] ACTIVE TCP CONNECTIONS (LISTENING PORTS)" -ForegroundColor Yellow
Write-Host ""
try {
    Get-NetTCPConnection -State Listen 2>$null | Sort-Object LocalPort | ForEach-Object {
        $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
        $pname = if ($proc) { $proc.ProcessName } else { "Unknown" }
        Write-Host ("  Port {0,-5} {1,-8} PID:{2,-6} {3}" -f $_.LocalPort, $_.State, $_.OwningProcess, $pname)
    }
} catch {
    Write-Host "  (Run as Administrator for full TCP connection info)"
}
Write-Host ""

# ── Running Processes (Top by Memory) ──
Write-Host "[*] TOP PROCESSES BY MEMORY USAGE" -ForegroundColor Yellow
Write-Host ""
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 15 | ForEach-Object {
    $mb = [math]::Round($_.WorkingSet64 / 1MB, 1)
    Write-Host ("  {0,-25} PID:{1,-6} {2,8} MB" -f $_.ProcessName, $_.Id, $mb)
}
Write-Host ""

# ── Startup Programs ──
Write-Host "[*] STARTUP PROGRAMS (Registry Run Keys)" -ForegroundColor Yellow
Write-Host ""
$runPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
)
foreach ($path in $runPaths) {
    if (Test-Path $path) {
        $items = Get-ItemProperty $path
        $items.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" } | ForEach-Object {
            Write-Host "  $($_.Name) -> $($_.Value)" -ForegroundColor Gray
        }
    }
}
Write-Host ""

# ── Stored Credentials ──
Write-Host "[*] STORED CREDENTIALS (cmdkey)" -ForegroundColor Yellow
Write-Host ""
cmdkey /list 2>$null
Write-Host ""

Write-Host "============================================" -ForegroundColor Green
Write-Host " STAGE 01 COMPLETE - EXITING IN 3 SECONDS" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green

# Cierre automático con delay
Start-Sleep -Seconds 3
Exit