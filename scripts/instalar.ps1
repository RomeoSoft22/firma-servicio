# Prepara los tres componentes la primera vez: dependencias, .env seguro y base de datos.
# Requisitos: .NET 8 SDK, PHP 8.2+ (con php.ini configurado), Composer y Node.js 20+.
$ErrorActionPreference = 'Stop'
$base = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

foreach ($cmd in 'dotnet', 'php', 'composer', 'npm') {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { throw "Falta '$cmd'. Revise los requisitos en el README." }
}

Write-Host "== Agente (firma-agente)" -ForegroundColor Cyan
dotnet build (Join-Path $base 'firma-agente') -nologo -v q
if ($LASTEXITCODE -ne 0) { throw 'No se pudo compilar el agente' }

Write-Host "== API (firma-api)" -ForegroundColor Cyan
Push-Location (Join-Path $base 'firma-api')
try {
    composer install --no-interaction --no-dev --optimize-autoloader
    if (-not (Test-Path .env)) {
        Copy-Item .env.example .env
        # Seguridad: sin modo depuración y mensajes en español.
        $env_ = (Get-Content .env) -replace '^APP_NAME=.*', 'APP_NAME=FirmaDigital' `
            -replace '^APP_ENV=.*', 'APP_ENV=production' -replace '^APP_DEBUG=.*', 'APP_DEBUG=false' `
            -replace '^APP_LOCALE=.*', 'APP_LOCALE=es' -replace '^APP_FALLBACK_LOCALE=.*', 'APP_FALLBACK_LOCALE=es'
        $env_ += 'CORS_ORIGINS=http://localhost:4200,http://127.0.0.1:4200'
        [IO.File]::WriteAllLines((Join-Path (Get-Location) '.env'), $env_, (New-Object Text.UTF8Encoding $false))
        php artisan key:generate --force
    }
    if (-not (Test-Path database\database.sqlite)) { New-Item database\database.sqlite -ItemType File | Out-Null }
    php artisan migrate --seed --force
} finally { Pop-Location }

Write-Host "== Front (firma-web)" -ForegroundColor Cyan
Push-Location (Join-Path $base 'firma-web')
try { npm install --no-audit --no-fund } finally { Pop-Location }

Write-Host "`nListo. Inicie todo con: .\firma-servicio\scripts\iniciar.ps1" -ForegroundColor Green
