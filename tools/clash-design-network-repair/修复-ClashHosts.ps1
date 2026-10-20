#requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Apply,
    [string]$Proxy = 'http://127.0.0.1:7897',
    [string]$HostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
)
$ErrorActionPreference = 'Stop'
$targetPatterns = @(
    '^0\.0\.0\.1\s+api\.mcneel\.com127\.0\.0\.1\s+api\.mcneel\.com$',
    '^0\.0\.0\.1\s+api\.mcneel\.com$',
    '^0\.0\.0\.1\s+api\.mcneel\.com/license/invalidate$',
    '^127\.0\.0\.1\s+api\.mcneel\.com$'
)
function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Test-Endpoint([string]$Route, [string]$Url) {
    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if (-not $curl) { Write-Host 'curl.exe not found; skipped.' -ForegroundColor Yellow; return }
    if ($Route -eq 'Direct') {
        $result = & $curl.Source --noproxy '*' --max-time 12 -sS -o NUL -w '%{http_code}' $Url 2>$null
    } else {
        $result = & $curl.Source --proxy $Proxy --max-time 12 -sS -o NUL -w '%{http_code}' $Url 2>$null
    }
    if ($LASTEXITCODE -eq 0) { Write-Host ("{0}: HTTP {1}" -f $Route, ($result -join '')) }
    else { Write-Host ("{0}: connection failed (curl exit {1})" -f $Route, $LASTEXITCODE) -ForegroundColor Yellow }
}
if (-not (Test-Path -LiteralPath $HostsPath -PathType Leaf)) { throw "Hosts file not found: $HostsPath" }
$bytes = [IO.File]::ReadAllBytes($HostsPath)
$encoding = [Text.UTF8Encoding]::new($false); $offset = 0
if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    $encoding = [Text.UTF8Encoding]::new($true); $offset = 3
} elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
    $encoding = [Text.UnicodeEncoding]::new($false, $true); $offset = 2
} elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
    $encoding = [Text.UnicodeEncoding]::new($true, $true); $offset = 2
}
$text = $encoding.GetString($bytes, $offset, $bytes.Length - $offset)
$crlf = [string][char]13 + [char]10
$lf = [string][char]10
$cr = [string][char]13
$newline = if ($text.Contains($crlf)) { $crlf } elseif ($text.Contains($cr)) { $cr } else { $lf }
$finalNewline = $text.EndsWith($lf) -or $text.EndsWith($cr)
$separatorRegex = [regex]::Escape($crlf) + '|' + [regex]::Escape($lf) + '|' + [regex]::Escape($cr)
$lines = @([regex]::Split($text, $separatorRegex))
if ($finalNewline -and $lines.Count -gt 0 -and $lines[-1] -eq '') { $lines = @($lines[0..($lines.Count - 2)]) }
$matches = @($lines | Where-Object { $line = $_.Trim(); $targetPatterns | Where-Object { $line -match $_ } })
Write-Host ("Exact blocking entries found: {0}" -f $matches.Count)
if ($Apply) {
    if (-not (Test-IsAdministrator)) { throw 'Open PowerShell as Administrator and rerun with -Apply.' }
    if ($matches.Count -gt 0) {
        $kept = @($lines | Where-Object { $line = $_.Trim(); -not ($targetPatterns | Where-Object { $line -match $_ }) })
        $backup = "$HostsPath.codex-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss-fff')"
        [IO.File]::Copy($HostsPath, $backup, $false)
        $updated = $kept -join $newline
        if ($finalNewline) { $updated += $newline }
        [IO.File]::WriteAllText($HostsPath, $updated, $encoding)
        Write-Host "Removed exact matches. Backup: $backup" -ForegroundColor Green
    } else { Write-Host 'No matching lines; hosts file unchanged.' }
}
$proxyState = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
$proxyEnabled = $proxyState.ProxyEnable -eq 1
$proxyExpected = $proxyState.ProxyServer -match '127\.0\.0\.1:7897|localhost:7897'
Write-Host ("Windows system proxy enabled: {0}; expected local Clash port: {1}" -f $proxyEnabled, [bool]$proxyExpected)
Test-Endpoint 'Direct' 'https://api.mcneel.com'
Test-Endpoint 'Clash' 'https://api.mcneel.com'
Write-Host 'No Adobe licensing, app, firewall, or Clash configuration is changed.'
if (-not $Apply) { Write-Host 'Preview only. Use -Apply from an elevated PowerShell only when these exact bad entries are present.' -ForegroundColor Cyan }
