<#
.SYNOPSIS
    Reclaim disk space by archiving old log files.
.DESCRIPTION
    Finds files older than N days in a log folder, zips them into a dated
    archive, then deletes the originals. Defaults to preview (-WhatIf) mode,
    so you see what WOULD happen before anything is touched. IIS logs are the
    usual suspect — they never stop growing until someone deals with them.
.EXAMPLE
    .\Clear-OldLogs.ps1 -LogPath C:\inetpub\logs\LogFiles -DaysOld 30 -WhatIf
    .\Clear-OldLogs.ps1 -LogPath C:\inetpub\logs\LogFiles -DaysOld 30
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$LogPath = 'C:\inetpub\logs\LogFiles',
    [int]$DaysOld = 30,
    [string]$ArchivePath = (Join-Path $env:TEMP 'log-archive')
)

if (-not (Test-Path $LogPath)) {
    Write-Host "Log path not found: $LogPath" -ForegroundColor Red
    exit 1
}

$cutoff = (Get-Date).AddDays(-$DaysOld)
$old = Get-ChildItem $LogPath -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt $cutoff }

if (-not $old) {
    Write-Host "No files older than $DaysOld days. Nothing to do." -ForegroundColor Green
    return
}

$totalMB = [math]::Round((($old | Measure-Object Length -Sum).Sum / 1MB), 1)
Write-Host ("Found {0} files older than {1} days ({2} MB)." -f $old.Count, $DaysOld, $totalMB) `
    -ForegroundColor Yellow

if ($PSCmdlet.ShouldProcess("$($old.Count) files", "Archive to $ArchivePath and delete originals")) {
    New-Item $ArchivePath -ItemType Directory -Force | Out-Null
    $zip = Join-Path $ArchivePath ("logs-{0:yyyyMMdd}.zip" -f (Get-Date))
    Compress-Archive -Path $old.FullName -DestinationPath $zip -Update
    $old | Remove-Item -Force
    Write-Host ("Archived to {0}; originals removed." -f $zip) -ForegroundColor Green
}
