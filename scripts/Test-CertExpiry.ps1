<#
.SYNOPSIS
    Check SSL certificate expiry dates before they become outages.
.DESCRIPTION
    Connects to each host:port, grabs the presented certificate, and reports
    days until expiry. Expired certs on a Friday night are how you learn this
    script should exist. Inspection only — it accepts any cert to read it,
    it never changes trust settings.
.EXAMPLE
    .\Test-CertExpiry.ps1
    .\Test-CertExpiry.ps1 -WarnDays 60
#>
param(
    [int]$WarnDays = 30,
    [array]$Targets = @(
        @{ Host = 'web01'; Port = 443 },
        @{ Host = 'mail01'; Port = 443 }
    )
)

Write-Host "`n=== SSL CERTIFICATE EXPIRY (warn under $WarnDays days) ===" -ForegroundColor Cyan

foreach ($t in $Targets) {
    $client = New-Object Net.Sockets.TcpClient
    try {
        $iar = $client.BeginConnect($t.Host, $t.Port, $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne(5000)) { throw "connection timed out" }
        $client.EndConnect($iar)
        # Accept any certificate — we're inspecting it, not trusting it.
        $callback = { param($s, $c, $ch, $e) $true }
        $ssl = New-Object Net.Security.SslStream($client.GetStream(), $false, $callback)
        $ssl.AuthenticateAsClient($t.Host)
        $cert = [Security.Cryptography.X509Certificates.X509Certificate2]$ssl.Certificate
        $days = ($cert.NotAfter - (Get-Date)).Days
        $level = if ($days -lt 0) { 'CRIT' } elseif ($days -le $WarnDays) { 'WARN' } else { 'OK' }
        $status = if ($days -lt 0) { "EXPIRED $(-$days) days ago" } else { "$days days left" }
        $color = @{ OK = 'Green'; WARN = 'Yellow'; CRIT = 'Red' }[$level]
        Write-Host ("{0,-20}:{1,-6} " -f $t.Host, $t.Port) -NoNewline
        Write-Host ("{0}  (expires {1:yyyy-MM-dd})" -f $status, $cert.NotAfter) -ForegroundColor $color
        $ssl.Dispose()
    } catch {
        Write-Host ("{0,-20}:{1,-6} " -f $t.Host, $t.Port) -NoNewline
        Write-Host ("UNREACHABLE: {0}" -f $_.Exception.Message) -ForegroundColor Red
    } finally {
        $client.Close()
    }
}
Write-Host ""
