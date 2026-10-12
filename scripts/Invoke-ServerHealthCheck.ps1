<#
.SYNOPSIS
    Quick server health check — CPU, memory, disk, services, and recent errors.
.DESCRIPTION
    Read-only health snapshot for Windows servers and workstations.
    Born from years of remote server support: the first five things you check
    when someone says "the server is slow."
.NOTES
    Run from an elevated PowerShell prompt for full event-log access.
#>

function Write-Status {
    param([string]$Label, [string]$Value, [string]$Level = 'OK')
    $color = switch ($Level) {
        'OK'   { 'Green' }
        'WARN' { 'Yellow' }
        'CRIT' { 'Red' }
        default { 'White' }
    }
    Write-Host ("{0,-28} " -f $Label) -NoNewline
    Write-Host $Value -ForegroundColor $color
}

Write-Host "`n=== SERVER HEALTH CHECK ===" -ForegroundColor Cyan
Write-Host ("Host: {0}   Time: {1}`n" -f $env:COMPUTERNAME, (Get-Date))

# --- CPU ---
$cpu = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
$cpuLevel = if ($cpu -ge 90) { 'CRIT' } elseif ($cpu -ge 75) { 'WARN' } else { 'OK' }
Write-Status 'CPU Load' ("{0}%" -f [math]::Round($cpu, 1)) $cpuLevel

# --- Memory ---
$os = Get-CimInstance Win32_OperatingSystem
$memUsedPct = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 1)
$memLevel = if ($memUsedPct -ge 90) { 'CRIT' } elseif ($memUsedPct -ge 80) { 'WARN' } else { 'OK' }
Write-Status 'Memory Used' ("{0}% ({1:N1} GB free of {2:N1} GB)" -f
    $memUsedPct, ($os.FreePhysicalMemory / 1048576), ($os.TotalVisibleMemorySize / 1048576)) $memLevel

# --- Disk ---
Write-Host "`n-- Disk --" -ForegroundColor Cyan
Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
    $pctFree = [math]::Round(($_.FreeSpace / $_.Size) * 100, 1)
    $level = if ($pctFree -le 5) { 'CRIT' } elseif ($pctFree -le 15) { 'WARN' } else { 'OK' }
    Write-Status ("Drive " + $_.DeviceID) ("{0}% free ({1:N1} GB of {2:N1} GB)" -f
        $pctFree, ($_.FreeSpace / 1GB), ($_.Size / 1GB)) $level
}

# --- Automatic services that aren't running ---
Write-Host "`n-- Services (Automatic, not running) --" -ForegroundColor Cyan
$bad = Get-Service | Where-Object { $_.StartType -eq 'Automatic' -and $_.Status -ne 'Running' }
if ($bad) {
    $bad | ForEach-Object { Write-Status $_.Name $_.Status 'CRIT' }
} else {
    Write-Host 'All automatic services running.' -ForegroundColor Green
}

# --- Top CPU consumers ---
Write-Host "`n-- Top 5 CPU processes --" -ForegroundColor Cyan
Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 |
    Format-Table @{l = 'Process'; e = { $_.ProcessName } },
                 @{l = 'CPU(s)';  e = { if ($_.CPU) { [math]::Round($_.CPU, 1) } else { 0 } } },
                 @{l = 'Mem(MB)'; e = { [math]::Round($_.WorkingSet / 1MB, 1) } } -AutoSize

# --- Recent System errors ---
Write-Host "-- Recent System log errors (24h) --" -ForegroundColor Cyan
$errs = Get-WinEvent -FilterHashtable @{LogName = 'System'; Level = 2; StartTime = (Get-Date).AddHours(-24) } `
    -MaxEvents 10 -ErrorAction SilentlyContinue
if ($errs) {
    $errs | Format-Table TimeCreated, Id, ProviderName, Message -AutoSize -Wrap
} else {
    Write-Host 'No errors in the last 24 hours.' -ForegroundColor Green
}

Write-Host "`n=== END ===`n" -ForegroundColor Cyan
