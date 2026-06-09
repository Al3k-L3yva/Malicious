<#
.SYNOPSIS
    Stage 06 — Network Discovery (Real Actions)
.DESCRIPTION
    Performs real network discovery: ping sweep of subnet, ARP table
    enumeration, DNS cache inspection, NetBIOS discovery, and SMB
    share enumeration on discovered hosts.
#>

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " STAGE 06: NETWORK DISCOVERY" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ── Get Local IP & Subnet ──
Write-Host "[*] DETERMINING LOCAL NETWORK" -ForegroundColor Yellow
$adapters = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
$localIP = ""
$subnetCIDR = ""

foreach ($adapter in $adapters) {
    if ($adapter.IPAddress) {
        $ip = $adapter.IPAddress | Select-Object -First 1
        $mask = $adapter.IPSubnet | Select-Object -First 1
        if ($ip -and $ip -notlike "127.*" -and $ip -notlike "169.254.*") {
            $localIP = $ip
            $parts = $ip -split '\.'
            $subnetCIDR = "$($parts[0]).$($parts[1]).$($parts[2])"
            Write-Host "  Local IP:   $ip"
            Write-Host "  Subnet:     $subnetCIDR.0/24"
            Write-Host "  Gateway:    $($adapter.DefaultIPGateway -join ', ')"
            break
        }
    }
}
Write-Host ""

# ── ARP Table ──
Write-Host "[*] ARP TABLE (NEIGHBOR DISCOVERY)" -ForegroundColor Yellow
$arpOutput = arp -a 2>$null
Write-Host $arpOutput
Write-Host ""

# ── Ping Sweep ──
if ($subnetCIDR) {
    Write-Host "[*] PING SWEEP: $subnetCIDR.1-30" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Scanning first 30 hosts..." -ForegroundColor Gray
    
    $jobs = @()
    $results = @()
    $sync = [System.Collections.Hashtable]::Synchronized(@{})
    
    for ($i = 1; $i -le 30; $i++) {
        $ip = "$subnetCIDR.$i"
        $job = Start-Job -ScriptBlock {
            param($target)
            $ping = Test-Connection -ComputerName $target -Count 1 -Quiet -ErrorAction SilentlyContinue
            if ($ping) {
                try {
                    $name = [System.Net.Dns]::GetHostEntry($target).HostName
                } catch {
                    $name = ""
                }
                return @{IP = $target; Name = $name}
            }
            return $null
        } -ArgumentList $ip
        $jobs += $job
    }
    
    Write-Host "  Waiting for responses..." -ForegroundColor Gray
    $jobs | ForEach-Object { $_ | Wait-Job -Timeout 5 | Out-Null }
    
    $results = $jobs | Where-Object { $_.State -eq "Completed" } | ForEach-Object {
        $result = Receive-Job $_
        if ($result) {
            if ($result.Name) {
                Write-Host "  [+] $($result.IP)  →  $($result.Name)" -ForegroundColor Green
            } else {
                Write-Host "  [+] $($result.IP)" -ForegroundColor Green
            }
        }
        Remove-Job $_ -ErrorAction SilentlyContinue
    }
    
    # Clean up stuck jobs
    $jobs | Where-Object { $_.State -ne "Completed" } | ForEach-Object {
        Stop-Job $_ -ErrorAction SilentlyContinue
        Remove-Job $_ -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "  [-] Could not determine local subnet" -ForegroundColor Red
}
Write-Host ""

# ── DNS Cache ──
Write-Host "[*] DNS CACHE" -ForegroundColor Yellow
$dnsCache = ipconfig /displaydns 2>$null
Write-Host $dnsCache
Write-Host ""

# ── NetBIOS ──
Write-Host "[*] NETBIOS NAME TABLE" -ForegroundColor Yellow
nbtstat -n 2>$null
Write-Host ""

# ── Active Network Sessions ──
Write-Host "[*] ACTIVE NETWORK SESSIONS" -ForegroundColor Yellow
net session 2>$null
Write-Host ""
net use 2>$null
Write-Host ""

# ── Hosts File ──
Write-Host "[*] HOSTS FILE" -ForegroundColor Yellow
Get-Content "$env:SystemRoot\System32\drivers\etc\hosts" -ErrorAction SilentlyContinue | Where-Object { $_ -notmatch '^\s*#' -and $_.Trim() -ne '' } | ForEach-Object {
    Write-Host "  $_"
}
Write-Host ""

Write-Host "============================================" -ForegroundColor Green
Write-Host " STAGE 06 COMPLETE" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green