<#
.SYNOPSIS
    AD hygiene report — stale, locked, and risky user accounts.
.DESCRIPTION
    Surfaces the accounts every admin should review quarterly: disabled
    accounts still hanging around, locked-out users, accounts inactive 90+
    days, and enabled accounts with passwords set to never expire.
    Read-only. Nothing is changed.
.NOTES
    Requires the ActiveDirectory module (RSAT), run from a domain-joined machine.
#>
param(
    [int]$InactiveDays = 90
)

if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Host "ActiveDirectory module not found. Install the RSAT Active Directory tools first." -ForegroundColor Red
    exit 1
}

$cutoff = (Get-Date).AddDays(-$InactiveDays)
Write-Host "`n=== AD HYGIENE REPORT (inactive > $InactiveDays days) ===" -ForegroundColor Cyan

$users = Get-ADUser -Filter * -Properties Enabled, LockedOut, LastLogonDate, PasswordNeverExpires

function Show-Section {
    param([string]$Title, $List, [string[]]$Props)
    Write-Host ("`n-- {0} ({1}) --" -f $Title, $List.Count) -ForegroundColor Yellow
    if ($List.Count -eq 0) {
        Write-Host "None. Nice." -ForegroundColor Green
        return
    }
    $List | Select-Object $Props | Format-Table -AutoSize
}

Show-Section "Disabled accounts" `
    ($users | Where-Object { -not $_.Enabled }) `
    @('SamAccountName', 'Name', 'LastLogonDate')

Show-Section "Locked out" `
    ($users | Where-Object { $_.LockedOut }) `
    @('SamAccountName', 'Name')

Show-Section "Inactive $InactiveDays+ days (still enabled)" `
    ($users | Where-Object { $_.Enabled -and (-not $_.LastLogonDate -or $_.LastLogonDate -lt $cutoff) }) `
    @('SamAccountName', 'Name', 'LastLogonDate')

Show-Section "Password never expires (enabled)" `
    ($users | Where-Object { $_.Enabled -and $_.PasswordNeverExpires }) `
    @('SamAccountName', 'Name')

Write-Host "`n=== END ===`n" -ForegroundColor Cyan
