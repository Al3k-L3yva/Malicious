Write-Host "============================================" -ForegroundColor Cyan
Write-Host " DEFENSE: PERSISTENCE DETECTION" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# -- 1. DETECT PAYLOAD FILES IN TEMP DIRECTORIES --
Write-Host "[*] SCANNING FOR SUSPICIOUS PAYLOAD FILES" -ForegroundColor Yellow
$suspiciousFiles = @(
    "$env:USERPROFILE\AppData\Local\Temp\outbreak_stage.ps1",
    "$env:TEMP\outbreak_stage.ps1",
    "$env:TEMP\*beacon*.ps1",
    "$env:TEMP\*payload*.ps1",
    "$env:USERPROFILE\AppData\Local\Temp\*.ps1"
)

$payloadFound = $false
foreach ($pattern in $suspiciousFiles) {
    $files = Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-1) }
    
    if ($files) {
        $payloadFound = $true
        foreach ($file in $files) {
            Write-Host "  [!] SUSPICIOUS PAYLOAD FOUND" -ForegroundColor Red
            Write-Host "      Path: $($file.FullName)" -ForegroundColor Yellow
            Write-Host "      Size: $([math]::Round($file.Length / 1KB, 1)) KB" -ForegroundColor Gray
            Write-Host "      Modified: $($file.LastWriteTime)" -ForegroundColor Gray
            
            # Check content for beacon/C2 patterns
            $content = Get-Content $file.FullName -ErrorAction SilentlyContinue
            if ($content -match 'Invoke-WebRequest|beacon|C2|127.0.0.1:5000') {
                Write-Host "      Content contains C2/beacon patterns!" -ForegroundColor Red
            }
            Write-Host ""
        }
    }
}

if (-not $payloadFound) {
    Write-Host "  [+] No suspicious payload files detected" -ForegroundColor Green
}
Write-Host ""

# -- 2. DETECT REGISTRY RUN KEYS --
Write-Host "[*] CHECKING REGISTRY RUN KEYS FOR PERSISTENCE" -ForegroundColor Yellow
$runPaths = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
)

$suspiciousRunKeys = @()
foreach ($runPath in $runPaths) {
    if (Test-Path $runPath) {
        $properties = Get-ItemProperty -Path $runPath -ErrorAction SilentlyContinue
        $propertyNames = $properties.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' }
        
        foreach ($prop in $propertyNames) {
            $value = $prop.Value
            # Check for suspicious patterns
            if ($value -match 'outbreak|beacon|temp|hidden|bypass|powershell.*-File|vbs|wscript') {
                $suspiciousRunKeys += [PSCustomObject]@{
                    Path = $runPath
                    Name = $prop.Name
                    Value = $value
                }
            }
        }
    }
}

if ($suspiciousRunKeys) {
    Write-Host "  [!] SUSPICIOUS REGISTRY RUN KEYS DETECTED" -ForegroundColor Red
    $suspiciousRunKeys | ForEach-Object {
        Write-Host "      Registry: $($_.Path)\$($_.Name)" -ForegroundColor Yellow
        Write-Host "      Command: $($_.Value)" -ForegroundColor Gray
        Write-Host ""
    }
} else {
    Write-Host "  [+] No suspicious registry run keys detected" -ForegroundColor Green
}
Write-Host ""

# -- 3. DETECT SCHEDULED TASKS --
Write-Host "[*] CHECKING FOR SUSPICIOUS SCHEDULED TASKS" -ForegroundColor Yellow
$allTasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
    $_.TaskPath -notlike "*\Microsoft\*"
}

$suspiciousTasks = @()
foreach ($task in $allTasks) {
    $taskName = $task.TaskName
    $actions = $task.Actions | ForEach-Object { $_.Execute + " " + $_.Arguments }
    $actionString = $actions -join " "
    
    # Check for suspicious patterns
    if ($taskName -match 'outbreak|health|check|update|beacon' -or
        $actionString -match 'outbreak|beacon|temp|hidden|bypass|powershell.*-File') {
        $suspiciousTasks += [PSCustomObject]@{
            Name = $taskName
            State = $task.State
            Actions = $actionString
            Triggers = ($task.Triggers | ForEach-Object { $_.CimClass.CimClassName }) -join ", "
        }
    }
}

if ($suspiciousTasks) {
    Write-Host "  [!] SUSPICIOUS SCHEDULED TASKS DETECTED" -ForegroundColor Red
    $suspiciousTasks | ForEach-Object {
        Write-Host "      Task: $($_.Name)" -ForegroundColor Yellow
        Write-Host "      State: $($_.State)" -ForegroundColor Gray
        Write-Host "      Actions: $($_.Actions)" -ForegroundColor Gray
        Write-Host "      Triggers: $($_.Triggers)" -ForegroundColor Gray
        Write-Host ""
    }
} else {
    Write-Host "  [+] No suspicious scheduled tasks detected" -ForegroundColor Green
}
Write-Host ""

# -- 4. DETECT STARTUP FOLDER SHORTCUTS --
Write-Host "[*] CHECKING STARTUP FOLDERS" -ForegroundColor Yellow
$startupPaths = @(
    [Environment]::GetFolderPath("Startup"),
    "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
)

$startupThreats = $false
foreach ($startupPath in $startupPaths) {
    if (Test-Path $startupPath) {
        $items = Get-ChildItem -Path $startupPath -File -ErrorAction SilentlyContinue
        
        foreach ($item in $items) {
            $isSuspicious = $false
            $reason = ""
            
            # Check file name
            if ($item.Name -match 'outbreak|helper|update|beacon') {
                $isSuspicious = $true
                $reason = "Suspicious filename"
            }
            
            # Check if it's a URL shortcut pointing to temp
            if ($item.Extension -eq ".url") {
                $content = Get-Content $item.FullName -ErrorAction SilentlyContinue
                if ($content -match 'file:///.*/Temp/|file:///.*/tmp/') {
                    $isSuspicious = $true
                    $reason = "URL shortcut pointing to temp directory"
                }
            }
            
            # Check if it's a shortcut to PowerShell with hidden window
            if ($item.Extension -eq ".lnk") {
                try {
                    $shell = New-Object -ComObject WScript.Shell
                    $shortcut = $shell.CreateShortcut($item.FullName)
                    if ($shortcut.TargetPath -match 'powershell|cmd' -and
                        $shortcut.Arguments -match 'hidden|bypass|temp') {
                        $isSuspicious = $true
                        $reason = "Shortcut to hidden PowerShell execution"
                    }
                } catch {}
            }
            
            if ($isSuspicious) {
                $startupThreats = $true
                Write-Host "  [!] SUSPICIOUS STARTUP ITEM" -ForegroundColor Red
                Write-Host "      File: $($item.FullName)" -ForegroundColor Yellow
                Write-Host "      Reason: $reason" -ForegroundColor Yellow
                Write-Host "      Modified: $($item.LastWriteTime)" -ForegroundColor Gray
                Write-Host ""
            }
        }
    }
}

if (-not $startupThreats) {
    Write-Host "  [+] No suspicious startup items detected" -ForegroundColor Green
}
Write-Host ""

# -- 5. DETECT POWERSHELL EVENTS RELATED TO PERSISTENCE --
Write-Host "[*] CHECKING POWERSHELL LOGS FOR PERSISTENCE COMMANDS" -ForegroundColor Yellow
$persistencePatterns = @(
    'Set-ItemProperty.*Run',
    'New-ItemProperty.*Run',
    'Register-ScheduledTask',
    'schtasks /create',
    'Set-Content.*\.url',
    'New-Object.*WScript\.Shell',
    'CreateShortcut'
)

$psEvents = Get-WinEvent -FilterHashtable @{
    LogName   = 'Microsoft-Windows-PowerShell/Operational'
    ID        = 4104
    StartTime = (Get-Date).AddHours(-6)
} -ErrorAction SilentlyContinue

$persistenceCommands = @()
if ($psEvents) {
    foreach ($event in $psEvents) {
        $message = $event.Message
        foreach ($pattern in $persistencePatterns) {
            if ($message -match $pattern) {
                $persistenceCommands += [PSCustomObject]@{
                    Time = $event.TimeCreated
                    Pattern = $pattern
                    Command = $message.Substring(0, [Math]::Min(200, $message.Length))
                }
                break
            }
        }
    }
}

if ($persistenceCommands) {
    Write-Host "  [!] PERSISTENCE COMMANDS DETECTED IN LOGS" -ForegroundColor Red
    $persistenceCommands | Select-Object -First 10 | ForEach-Object {
        Write-Host "      Time: $($_.Time)" -ForegroundColor Yellow
        Write-Host "      Pattern: $($_.Pattern)" -ForegroundColor Yellow
        Write-Host "      Command: $($_.Command)..." -ForegroundColor Gray
        Write-Host ""
    }
} else {
    Write-Host "  [+] No persistence commands detected in PowerShell logs" -ForegroundColor Green
}
Write-Host ""

# -- 6. DETECT HIDDEN POWERSHELL PROCESSES --
Write-Host "[*] CHECKING FOR HIDDEN POWERSHELL PROCESSES" -ForegroundColor Yellow
$psProcesses = Get-Process -Name powershell, pwsh -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowTitle -eq '' -and $_.StartTime -gt (Get-Date).AddHours(-1) }

$hiddenPsFound = $false
foreach ($proc in $psProcesses) {
    try {
        $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId=$($proc.Id)").CommandLine
        if ($cmdLine -match 'hidden|windowstyle|outbreak|beacon|temp') {
            $hiddenPsFound = $true
            Write-Host "  [!] HIDDEN POWERSHELL PROCESS" -ForegroundColor Red
            Write-Host "      PID: $($proc.Id)" -ForegroundColor Yellow
            Write-Host "      Started: $($proc.StartTime)" -ForegroundColor Gray
            Write-Host "      Command: $cmdLine" -ForegroundColor Gray
            Write-Host ""
        }
    } catch { continue }
}

if (-not $hiddenPsFound) {
    Write-Host "  [+] No hidden PowerShell processes detected" -ForegroundColor Green
}
Write-Host ""

# -- 7. CHECK FOR RECENT REGISTRY MODIFICATIONS --
Write-Host "[*] CHECKING RECENT REGISTRY MODIFICATIONS" -ForegroundColor Yellow
$regEvents = Get-WinEvent -FilterHashtable @{
    LogName   = 'Security'
    ID        = 4657  # Registry value modified
    StartTime = (Get-Date).AddHours(-6)
} -ErrorAction SilentlyContinue | Where-Object {
    $_.Message -match 'CurrentVersion\\Run|CurrentVersion\\RunOnce'
}

if ($regEvents) {
    Write-Host "  [!] REGISTRY RUN KEY MODIFICATIONS DETECTED" -ForegroundColor Red
    $regEvents | Select-Object -First 5 | ForEach-Object {
        Write-Host "      Time: $($_.TimeCreated)" -ForegroundColor Yellow
        Write-Host "      User: $($_.Properties[1].Value)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [+] No recent registry run key modifications detected" -ForegroundColor Green
}
Write-Host ""

# -- 8. VERIFY SPECIFIC OUTBREAK PERSISTENCE --
Write-Host "[*] VERIFYING SPECIFIC OUTBREAK PERSISTENCE MECHANISMS" -ForegroundColor Yellow
$outbreakDetected = $false

# Check for OutbreakUpdate registry key
$runPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$outbreakReg = Get-ItemProperty -Path $runPath -Name "OutbreakUpdate" -ErrorAction SilentlyContinue
if ($outbreakReg) {
    $outbreakDetected = $true
    Write-Host "  [!] OUTBREAK REGISTRY KEY FOUND" -ForegroundColor Red
    Write-Host "      Name: OutbreakUpdate" -ForegroundColor Yellow
    Write-Host "      Value: $($outbreakReg.OutbreakUpdate)" -ForegroundColor Gray
    Write-Host ""
}

# Check for OutbreakHealthCheck task
$outbreakTask = Get-ScheduledTask -TaskName "OutbreakHealthCheck" -ErrorAction SilentlyContinue
if ($outbreakTask) {
    $outbreakDetected = $true
    Write-Host "  [!] OUTBREAK SCHEDULED TASK FOUND" -ForegroundColor Red
    Write-Host "      Name: OutbreakHealthCheck" -ForegroundColor Yellow
    Write-Host "      State: $($outbreakTask.State)" -ForegroundColor Gray
    Write-Host ""
}

# Check for OutbreakHelper.url
$startupPath = [Environment]::GetFolderPath("Startup")
$outbreakShortcut = "$startupPath\OutbreakHelper.url"
if (Test-Path $outbreakShortcut) {
    $outbreakDetected = $true
    Write-Host "  [!] OUTBREAK STARTUP SHORTCUT FOUND" -ForegroundColor Red
    Write-Host "      Path: $outbreakShortcut" -ForegroundColor Yellow
    Write-Host ""
}

if (-not $outbreakDetected) {
    Write-Host "  [+] No Outbreak-specific persistence mechanisms detected" -ForegroundColor Green
}
Write-Host ""

# -- SUMMARY --
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " DETECTION SUMMARY" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

$totalThreats = $persistenceCommands.Count + $suspiciousRunKeys.Count + $suspiciousTasks.Count

if ($outbreakDetected -or $totalThreats -gt 0 -or $payloadFound -or $startupThreats -or $hiddenPsFound) {
    Write-Host "  [!] PERSISTENCE MECHANISMS DETECTED" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Immediate actions recommended:" -ForegroundColor Yellow
    Write-Host "  1. Remove suspicious registry run keys" -ForegroundColor White
    Write-Host "  2. Delete unauthorized scheduled tasks" -ForegroundColor White
    Write-Host "  3. Remove startup folder shortcuts" -ForegroundColor White
    Write-Host "  4. Delete payload files from temp directories" -ForegroundColor White
    Write-Host "  5. Kill hidden PowerShell processes" -ForegroundColor White
    Write-Host "  6. Scan for additional persistence mechanisms" -ForegroundColor White
    Write-Host "  7. Reset credentials if compromise confirmed" -ForegroundColor White
} else {
    Write-Host "  [+] NO PERSISTENCE MECHANISMS DETECTED" -ForegroundColor Green
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host " DEFENSE SCAN COMPLETE" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Start-Sleep -Seconds 3
