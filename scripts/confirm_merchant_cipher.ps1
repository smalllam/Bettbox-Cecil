$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

$env:Path = @(
  "D:\Program Files\Git\bin",
  "H:\flutter\bin",
  $env:Path
) -join ';'

if (-not (Test-Path "config/merchant.secret")) {
  Write-Host "ERROR: missing config/merchant.secret" -ForegroundColor Red
  exit 1
}

Write-Host "=== Generate merchant cipher ===" -ForegroundColor Cyan
$dart = @("H:\flutter\bin\dart.bat", "C:\flutter\bin\dart.bat") | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $dart) {
  $cmd = Get-Command dart -ErrorAction SilentlyContinue
  if ($cmd) { $dart = $cmd.Source }
}
if (-not $dart) {
  Write-Host "ERROR: dart not found" -ForegroundColor Red
  exit 1
}

& $dart run tools/encrypt_merchant_config.dart
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$cipher = Get-Content "config/merchant.cipher.txt" -Raw
$bytes = [System.Text.Encoding]::UTF8.GetByteCount($cipher.Trim())

Write-Host ""
Write-Host "Cipher length: $bytes / 512 bytes" -ForegroundColor Yellow
Write-Host "DNS host: nt-2.sxr.pics (TXT)" -ForegroundColor Yellow
Write-Host ""

$answer = Read-Host "Confirm DNS TXT is updated and continue build? (y/N)"
if ($answer -notin @("y", "Y", "yes", "YES")) {
  Write-Host "Build cancelled." -ForegroundColor Red
  exit 1
}

Write-Host "Confirmed. Continue build." -ForegroundColor Green
