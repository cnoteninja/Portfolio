<#
.SYNOPSIS
    Audit local Administrators group membership across servers.
.DESCRIPTION
    Lists who holds local admin on each target machine. Stale admin rights are
    a security finding waiting to happen — run it, review it, trim it.
    Read-only. Nothing is changed.
.EXAMPLE
    .\Get-LocalAdminAudit.ps1
    .\Get-LocalAdminAudit.ps1 -Servers srv01,srv02
.NOTES
    Uses ADSI against remote machines; you need admin rights on the targets.
#>
param(
    [string[]]$Servers = @($env:COMPUTERNAME)
)

Write-Host "`n=== LOCAL ADMINISTRATORS AUDIT ===" -ForegroundColor Cyan

foreach ($s in $Servers) {
    Write-Host "`n-- $s --" -ForegroundColor Yellow
    try {
        $group = [ADSI]"WinNT://$s/Administrators,group"
        $members = @($group.psbase.Invoke("Members")) | ForEach-Object {
            $_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)
        } | Sort-Object
        if ($members.Count -eq 0) {
            Write-Host "  (no members found)" -ForegroundColor Yellow
        } else {
            $members | ForEach-Object { Write-Host "  $_" }
        }
    } catch {
        Write-Host "  UNREACHABLE: $($_.Exception.Message)" -ForegroundColor Red
    }
}
Write-Host ""
