<#
.SYNOPSIS
    Service-desk quick fixes for Windows workstations.
.DESCRIPTION
    The four safe, everyday fixes that resolve a surprising share of tickets:
    print spooler, DNS, temp files, and a disk-space report.
    Nothing exotic — that's the point. Run elevated.
#>
#Requires -RunAsAdministrator

Write-Host "`n=== WORKSTATION QUICK FIX ===" -ForegroundColor Cyan

# 1. Print spooler (the classic)
Write-Host "`n[1/4] Restarting Print Spooler..." -ForegroundColor Yellow
Restart-Service -Name Spooler -Force -ErrorAction SilentlyContinue
Write-Host ("Spooler status: {0}" -f (Get-Service Spooler).Status) -ForegroundColor Green

# 2. DNS flush
Write-Host "`n[2/4] Flushing DNS..." -ForegroundColor Yellow
ipconfig /flushdns | Out-Null
Write-Host "DNS cache flushed." -ForegroundColor Green

# 3. Temp file cleanup
Write-Host "`n[3/4] Clearing temp files..." -ForegroundColor Yellow
$before = (Get-ChildItem $env:TEMP -Recurse -ErrorAction SilentlyContinue |
    Measure-Object -Property Length -Sum).Sum
Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
$after = (Get-ChildItem $env:TEMP -Recurse -ErrorAction SilentlyContinue |
    Measure-Object -Property Length -Sum).Sum
$freed = [math]::Round((($before - $after) / 1MB), 1)
Write-Host ("Freed ~{0} MB from temp." -f $freed) -ForegroundColor Green

# 4. Disk space report
Write-Host "`n[4/4] Disk space:" -ForegroundColor Yellow
Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
    $pctFree = [math]::Round(($_.FreeSpace / $_.Size) * 100, 1)
    $color = if ($pctFree -le 10) { 'Red' } elseif ($pctFree -le 20) { 'Yellow' } else { 'Green' }
    Write-Host ("  {0}  {1}% free ({2:N1} GB free)" -f
        $_.DeviceID, $pctFree, ($_.FreeSpace / 1GB)) -ForegroundColor $color
}

Write-Host "`n=== DONE — reboot if issues persist ===`n" -ForegroundColor Cyan
