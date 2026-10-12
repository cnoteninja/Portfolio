<#
.SYNOPSIS
    Disk space report across multiple servers.
.DESCRIPTION
    Queries every fixed disk on each target server via CIM and flags anything
    under your warning threshold. Run it weekly and disk-full outages stop
    surprising you at 2 AM.
.EXAMPLE
    .\Get-DiskReport.ps1
    .\Get-DiskReport.ps1 -Servers dc01,fileserver01,sql01 -WarnPct 25
.NOTES
    Needs CIM/WinRM access to the target servers.
#>
param(
    [string[]]$Servers = @($env:COMPUTERNAME),
    [int]$WarnPct = 20,
    [int]$CritPct = 10
)

Write-Host "`n=== DISK SPACE REPORT ===" -ForegroundColor Cyan

$rows = foreach ($s in $Servers) {
    try {
        $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" `
            -ComputerName $s -ErrorAction Stop
        foreach ($d in $disks) {
            $pctFree = [math]::Round(($d.FreeSpace / $d.Size) * 100, 1)
            [pscustomobject]@{
                Server  = $s
                Drive   = $d.DeviceID
                PctFree = $pctFree
                FreeGB  = [math]::Round($d.FreeSpace / 1GB, 1)
                TotalGB = [math]::Round($d.Size / 1GB, 1)
                Status  = if ($pctFree -le $CritPct) { 'CRIT' }
                          elseif ($pctFree -le $WarnPct) { 'WARN' } else { 'OK' }
            }
        }
    } catch {
        [pscustomobject]@{
            Server  = $s
            Drive   = '-'
            PctFree = $null
            FreeGB  = $null
            TotalGB = $null
            Status  = "UNREACHABLE"
        }
    }
}

foreach ($r in $rows) {
    $color = switch ($r.Status) {
        'OK'   { 'Green' }
        'WARN' { 'Yellow' }
        default { 'Red' }
    }
    if ($r.Drive -eq '-') {
        Write-Host ("{0,-18} {1}" -f $r.Server, $r.Status) -ForegroundColor $color
    } else {
        Write-Host ("{0,-18} {1,-4} {2,5}% free ({3} GB of {4} GB)  " -f `
            $r.Server, $r.Drive, $r.PctFree, $r.FreeGB, $r.TotalGB) -NoNewline
        Write-Host $r.Status -ForegroundColor $color
    }
}
Write-Host ""
