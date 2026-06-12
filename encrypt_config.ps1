$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$env:Path = @(
    "D:\Program Files\Git\bin",
    "H:\flutter\bin",
    $env:Path
) -join ';'

$dartCandidates = @(
    "H:\flutter\bin\dart.bat",
    "$env:LOCALAPPDATA\flutter\bin\dart.bat",
    "C:\flutter\bin\dart.bat"
)

$dart = $dartCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $dart) {
    $found = Get-Command dart -ErrorAction SilentlyContinue
    if ($found) { $dart = $found.Source }
}

if (-not $dart) {
    Write-Host "ERROR: dart not found. Install Flutter or add dart to PATH." -ForegroundColor Red
    Write-Host "Manual command: dart run tools/encrypt_merchant_config.dart"
    exit 1
}

if (-not (Test-Path "config\merchant.secret")) {
    Write-Host "ERROR: missing config\merchant.secret. See config\merchant.secret.example." -ForegroundColor Red
    exit 1
}

Write-Host "Using: $dart" -ForegroundColor Gray
& $dart run tools/encrypt_merchant_config.dart
exit $LASTEXITCODE
