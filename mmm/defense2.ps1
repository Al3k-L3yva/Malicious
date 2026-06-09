<#
.SYNOPSIS
    Stage 01 — Auditoría Defensiva de Sistema y Red
.DESCRIPTION
    Evalúa la postura de seguridad del sistema, buscando configuraciones 
    inseguras, riesgos de persistencia, exceso de privilegios y credenciales expuestas.
.REQUIREMENTS
    Ejecutar como Administrador para obtener resultados precisos.
#>

# Verificar privilegios de Administrador
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[!] ADVERTENCIA: Ejecuta este script como Administrador para una auditoría completa." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
}

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " STAGE 01: AUDITORÍA DEFENSIVA DE SISTEMA Y RED" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

# ── 1. System Information & Uptime ──
Write-Host "[*] SISTEMA Y TIEMPO DE ACTIVIDAD (UPTIME)" -ForegroundColor Yellow
$os = Get-WmiObject Win32_OperatingSystem
$bootTime = [System.Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime)
$uptime = (Get-Date) - $bootTime

Write-Host "  OS: $($os.Caption) (Build: $($os.BuildNumber))"
Write-Host "  Uptime: $($uptime.Days) días, $($uptime.Hours) horas"

if ($uptime.Days -gt 30) {
    Write-Host "  [!] RIESGO: El sistema lleva más de 30 días sin reiniciarse. Posible falta de parches de seguridad." -ForegroundColor Red
} else {
    Write-Host "  [OK] El tiempo de actividad es razonable (políticas de parcheo probables)." -ForegroundColor Green
}
Write-Host ""

# ── 2. Local Users ──
Write-Host "[*] CUENTAS DE USUARIO LOCALES" -ForegroundColor Yellow
$users = Get-LocalUser
$guestEnabled = $users | Where-Object { $_.Name -eq 'Guest' -and $_.Enabled }

if ($guestEnabled) {
    Write-Host "  [!] CRÍTICO: La cuenta 'Invitado' (Guest) está HABILITADA." -ForegroundColor Red
} else {
    Write-Host "  [OK] La cuenta 'Invitado' está deshabilitada." -ForegroundColor Green
}

$emptyPasswordUsers = $users | Where-Object { $_.PasswordRequired -eq $false }
if ($emptyPasswordUsers) {
    Write-Host "  [!] RIESGO: Usuarios sin contraseña requerida: $($emptyPasswordUsers.Name -join ', ')" -ForegroundColor Red
} else {
    Write-Host "  [OK] Todas las cuentas requieren contraseña." -ForegroundColor Green
}
Write-Host ""

# ── 3. Administrators Group ──
Write-Host "[*] MIEMBROS DEL GRUPO DE ADMINISTRADORES" -ForegroundColor Yellow
$adminGroup = Get-LocalGroup | Where-Object { $_.SID -eq "S-1-5-32-544" }
$adminMembers = Get-LocalGroupMember -Group $adminGroup.Name -ErrorAction SilentlyContinue

Write-Host "  Total de administradores: $($adminMembers.Count)"
if ($adminMembers.Count -gt 2) {
    Write-Host "  [!] RIESGO: Exceso de administradores locales (>2). Principio de menor privilegio violado." -ForegroundColor Red
} else {
    Write-Host "  [OK] Número de administradores dentro de límites normales." -ForegroundColor Green
}

foreach ($member in $adminMembers) {
    $color = if ($member.Name -match "Administrator$") { "Gray" } else { "White" }
    Write-Host "    - $($member.Name) [$($member.ObjectClass)]" -ForegroundColor $color
}
Write-Host ""

# ── 4. Active Network Connections (Risky Ports) ──
Write-Host "[*] PUERTOS DE ESCUCHA DE ALTO RIESGO" -ForegroundColor Yellow
$riskyPorts = @(21, 23, 445, 3389, 5985, 5986) # FTP, Telnet, SMB, RDP, WinRM HTTP, WinRM HTTPS
$listeningPorts = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty LocalPort

$foundRisky = $riskyPorts | Where-Object { $listeningPorts -contains $_ }

if ($foundRisky) {
    Write-Host "  [!] ADVERTENCIA: Puertos de alto riesgo detectados en escucha: $($foundRisky -join ', ')" -ForegroundColor Red
    Write-Host "      -> Asegúrate de que el Firewall de Windows restrinja el acceso a estos puertos." -ForegroundColor Gray
} else {
    Write-Host "  [OK] No se detectaron puertos de alto riesgo (21, 23, 445, 3389, 5985, 5986) en escucha." -ForegroundColor Green
}
Write-Host ""

# ── 5. Running Processes (Suspicious Paths) ──
Write-Host "[*] PROCESOS EN EJECUCIÓN (Búsqueda de rutas sospechosas)" -ForegroundColor Yellow
$suspiciousPaths = @("\Temp\", "\AppData\", "\Downloads\")
$suspiciousProcs = Get-Process | Where-Object { 
    $_.Path -and ($suspiciousPaths | Where-Object { $_.Path -match [regex]::Escape($_) })
} | Select-Object -First 5 Name, Path, Id

if ($suspiciousProcs) {
    Write-Host "  [!] RIESGO: Procesos ejecutándose desde rutas temporales o de usuario:" -ForegroundColor Red
    foreach ($proc in $suspiciousProcs) {
        Write-Host "      PID $($proc.Id) | $($proc.Name) -> $($proc.Path)" -ForegroundColor Gray
    }
} else {
    Write-Host "  [OK] No se detectaron procesos obvios ejecutándose desde carpetas Temp/AppData." -ForegroundColor Green
}
Write-Host ""

# ── 6. Startup Programs (Persistence Check) ──
Write-Host "[*] PROGRAMAS DE INICIO (Riesgo de Persistencia)" -ForegroundColor Yellow
$runPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
)
$persistenceFound = $false

foreach ($path in $runPaths) {
    if (Test-Path $path) {
        $items = Get-ItemProperty $path -ErrorAction SilentlyContinue
        $items.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" -and $_.Value -match "(Temp|AppData|Downloads)" } | ForEach-Object {
            Write-Host "  [!] RIESGO DE PERSISTENCIA: $($_.Name) -> $($_.Value)" -ForegroundColor Red
            $persistenceFound = $true
        }
    }
}

if (-not $persistenceFound) {
    Write-Host "  [OK] No se encontraron entradas de inicio apuntando a rutas sospechosas (Temp/AppData)." -ForegroundColor Green
}
Write-Host ""

# ── 7. Stored Credentials ──
Write-Host "[*] CREDENCIALES ALMACENADAS (cmdkey)" -ForegroundColor Yellow
$cmdkeyOutput = cmdkey /list 2>$null | Out-String

if ($cmdkeyOutput -match "No saved credentials" -or $cmdkeyOutput -match "No hay credenciales guardadas") {
    Write-Host "  [OK] No hay credenciales almacenadas en el Administrador de Credenciales de Windows." -ForegroundColor Green
} else {
    Write-Host "  [!] CRÍTICO: Se encontraron credenciales almacenadas. Riesgo de movimiento lateral." -ForegroundColor Red
    Write-Host "      Resumen:" -ForegroundColor Gray
    cmdkey /list | Select-String "Target:" | ForEach-Object { Write-Host "        $($_.ToString().Trim())" -ForegroundColor Gray }
}
Write-Host ""

Write-Host "========================================================" -ForegroundColor Green
Write-Host " STAGE 01 COMPLETE - AUDITORÍA FINALIZADA" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host "Presiona [ENTER] para cerrar esta ventana..." -ForegroundColor Cyan
Read-Host
