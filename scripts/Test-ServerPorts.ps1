<#
.SYNOPSIS
    Check critical servers and ports — the morning "is everything up?" board.
.DESCRIPTION
    Tests TCP connectivity to a list of servers and the ports that matter on
    each, with a fast timeout so one dead host doesn't stall the whole check.
    Edit the built-in list or point it at a CSV with Server,Port,Label columns.
.EXAMPLE
    .\Test-ServerPorts.ps1
    .\Test-ServerPorts.ps1 -Config .\servers.csv
#>
param(
    [string]$Config = (Join-Path $PSScriptRoot 'servers.csv')
)

$targets = @(
    # Edit these, or use a CSV file with Server,Port,Label columns instead.
    [pscustomobject]@{ Server = 'dc01';         Port = 53;   Label = 'DNS' },
    [pscustomobject]@{ Server = 'dc01';         Port = 389;  Label = 'LDAP' },
    [pscustomobject]@{ Server = 'fileserver01'; Port = 445;  Label = 'SMB' },
    [pscustomobject]@{ Server = 'web01';        Port = 443;  Label = 'HTTPS' },
    [pscustomobject]@{ Server = 'sql01';        Port = 1433; Label = 'SQL' }
)

if (Test-Path $Config) {
    $csv = Import-Csv $Config
    if ($csv) { $targets = $csv }
}

Write-Host "`n=== SERVER / PORT CHECK ===" -ForegroundColor Cyan
$results = foreach ($t in $targets) {
    $tcp = New-Object Net.Sockets.TcpClient
    $connected = $false
    try {
        $iar = $tcp.BeginConnect($t.Server, [int]$t.Port, $null, $null)
        if ($iar.AsyncWaitHandle.WaitOne(3000)) {
            $tcp.EndConnect($iar)
            $connected = $true
        }
    } catch {
        $connected = $false
    } finally {
        $tcp.Close()
    }
    [pscustomobject]@{
        Server = $t.Server
        Port   = $t.Port
        Label  = $t.Label
        Status = if ($connected) { 'UP' } else { 'DOWN' }
    }
}

$results | ForEach-Object {
    $color = if ($_.Status -eq 'UP') { 'Green' } else { 'Red' }
    Write-Host ("{0,-18} port {1,-6} ({2,-8}) " -f $_.Server, $_.Port, $_.Label) -NoNewline
    Write-Host $_.Status -ForegroundColor $color
}

$down = ($results | Where-Object { $_.Status -eq 'DOWN' }).Count
Write-Host ""
if ($down -eq 0) {
    Write-Host ("All {0} checks passed." -f $results.Count) -ForegroundColor Green
} else {
    Write-Host ("{0} of {1} checks FAILED." -f $down, $results.Count) -ForegroundColor Red
}
