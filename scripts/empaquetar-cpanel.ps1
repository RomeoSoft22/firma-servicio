# Genera un .zip listo para subir a un hosting cPanel (Apache + PHP 8.3) con:
#   <Dominio>/   raíz pública: SPA Angular compilada, .htaccess, laravel.php y descargas/AgenteFirmaSetup.exe
#   firma-api/   Laravel fuera de la web, con vendor/, .env de producción y base SQLite ya creada
# No requiere consola SSH ni Composer en el hosting.
#
# Uso (con firma-agente, firma-api y firma-web clonados junto a firma-servicio):
#   powershell -ExecutionPolicy Bypass -File .\firma-servicio\scripts\empaquetar-cpanel.ps1 -Dominio firma.juarezcampos.net
param(
    [string]$Dominio = 'firma.juarezcampos.net',
    [string]$Base = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
    [string]$Salida = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'paquetes'),
    # Clave de administración (Historial y Configuración). Si se omite, se genera una aleatoria.
    [string]$ClaveAdmin = '',
    [switch]$SinAgente
)
$ErrorActionPreference = 'Stop'
$plantillas = Join-Path (Split-Path $PSScriptRoot -Parent) 'despliegue\cpanel'
$web = Join-Path $Base 'firma-web'
$api = Join-Path $Base 'firma-api'
$agente = Join-Path $Base 'firma-agente'

foreach ($cmd in 'php', 'composer', 'npm', 'tar') {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { throw "Falta '$cmd'." }
}
foreach ($d in $web, $api) { if (-not (Test-Path $d)) { throw "No existe $d (ejecute scripts\clonar.ps1)" } }

$fecha = Get-Date -Format 'yyyyMMdd-HHmm'
$trabajo = Join-Path $Salida "cpanel-$fecha"
$publico = Join-Path $trabajo $Dominio
$destApi = Join-Path $trabajo 'firma-api'
New-Item -ItemType Directory -Force $publico, $destApi | Out-Null

# ---------------------------------------------------------------- 1. Front (SPA)
Write-Host '== 1/4 Compilando el front (Angular, producción)' -ForegroundColor Cyan
Push-Location $web
try {
    if (-not (Test-Path node_modules)) { npm ci --no-audit --no-fund; if ($LASTEXITCODE) { throw 'npm ci falló' } }
    $env:NG_CLI_ANALYTICS = 'false'
    npx ng build --configuration production
    if ($LASTEXITCODE) { throw 'ng build falló' }
} finally { Pop-Location }
robocopy (Join-Path $web 'dist\front\browser') $publico /E /NFL /NDL /NJH /NJS | Out-Null
Copy-Item (Join-Path $plantillas 'publico.htaccess') (Join-Path $publico '.htaccess')
Copy-Item (Join-Path $plantillas 'laravel.php') $publico

# ---------------------------------------------------------------- 2. Instalador del agente
if (-not $SinAgente) {
    Write-Host '== 2/4 Instalador del Agente de Firma' -ForegroundColor Cyan
    $setup = Join-Path $agente 'instalador\salida\AgenteFirmaSetup.exe'
    if (-not (Test-Path $setup)) {
        powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $agente 'instalador\construir.ps1')
        if ($LASTEXITCODE) { throw 'No se pudo construir el instalador del agente' }
    }
    New-Item -ItemType Directory -Force (Join-Path $publico 'descargas') | Out-Null
    Copy-Item $setup (Join-Path $publico 'descargas\AgenteFirmaSetup.exe')
    # Versión publicada: el agente la consulta en «Buscar actualizaciones».
    $versionAgente = "$((Get-Item $setup).VersionInfo.ProductVersion)".Trim()
    if (-not $versionAgente) {
        $versionAgente = ([regex]::Match((Get-Content (Join-Path $agente 'instalador\AgenteFirma.iss') -Raw), '#define Version "([^"]+)"')).Groups[1].Value
    }
    @{ version = $versionAgente; archivo = '/descargas/AgenteFirmaSetup.exe' } | ConvertTo-Json |
        Set-Content (Join-Path $publico 'descargas\agente-version.json') -Encoding ascii
    Write-Host "   Agente publicado: versión $versionAgente"
} else {
    Write-Host '== 2/4 (omitido) Instalador del agente' -ForegroundColor DarkGray
}

# ---------------------------------------------------------------- 3. API (Laravel)
Write-Host '== 3/4 Preparando la API (Laravel)' -ForegroundColor Cyan
robocopy $api $destApi /E /XD vendor node_modules tests public .git .idea .vscode /XF .env database.sqlite *.log AGENTS.md CLAUDE.md phpunit.xml /NFL /NDL /NJH /NJS | Out-Null
# storage/: solo la estructura (los .gitignore), nunca archivos de usuarios
Get-ChildItem (Join-Path $destApi 'storage') -Recurse -File | Where-Object Name -ne '.gitignore' | Remove-Item -Force
Copy-Item (Join-Path $plantillas 'api.htaccess') (Join-Path $destApi '.htaccess')

Push-Location $destApi
try {
    composer install --no-dev --optimize-autoloader --no-interaction --no-progress
    if ($LASTEXITCODE) { throw 'composer install falló' }

    $origen = "https://$Dominio"
    if (-not $ClaveAdmin) {
        $bytes = New-Object byte[] 18
        [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
        $ClaveAdmin = [Convert]::ToBase64String($bytes) -replace '[+/=]', 'x'
    }
    if ($ClaveAdmin.Length -lt 12) { throw 'La clave de administración debe tener al menos 12 caracteres.' }
    $env_ = (Get-Content .env.example) `
        -replace '^ADMIN_CLAVE=.*', "ADMIN_CLAVE=`"$ClaveAdmin`"" `
        -replace '^APP_NAME=.*', 'APP_NAME=FirmaDigital' `
        -replace '^APP_ENV=.*', 'APP_ENV=production' `
        -replace '^APP_DEBUG=.*', 'APP_DEBUG=false' `
        -replace '^APP_URL=.*', "APP_URL=$origen" `
        -replace '^APP_LOCALE=.*', 'APP_LOCALE=es' `
        -replace '^APP_FALLBACK_LOCALE=.*', 'APP_FALLBACK_LOCALE=es' `
        -replace '^LOG_LEVEL=.*', 'LOG_LEVEL=warning' `
        -replace '^CORS_ORIGINS=.*', "CORS_ORIGINS=$origen"
    [IO.File]::WriteAllLines((Join-Path $destApi '.env'), $env_, (New-Object Text.UTF8Encoding $false))
    php artisan key:generate --force --no-interaction
    if ($LASTEXITCODE) { throw 'No se pudo generar APP_KEY' }

    # Base SQLite nueva con el esquema y los catálogos iniciales (motivos, parámetros).
    New-Item database\database.sqlite -ItemType File -Force | Out-Null
    php artisan migrate --seed --force --no-interaction
    if ($LASTEXITCODE) { throw 'Las migraciones fallaron' }
    php artisan optimize:clear | Out-Null
    Get-ChildItem storage\logs -File | Where-Object Name -ne '.gitignore' | Remove-Item -Force
} finally { Pop-Location }

# ---------------------------------------------------------------- 4. Comprimir
Write-Host '== 4/4 Comprimiendo' -ForegroundColor Cyan
$zip = Join-Path $Salida "firma-cpanel-$Dominio-$fecha.zip"
# tar (bsdtar de Windows) genera rutas con "/", compatibles con el extractor de cPanel.
tar -a -c -f $zip -C $trabajo $Dominio firma-api
if ($LASTEXITCODE) { throw 'No se pudo crear el .zip' }

# La clave se entrega aparte (nunca dentro del .zip publicado).
$archivoClave = Join-Path $Salida "CLAVE-ADMIN-$Dominio-$fecha.txt"
Set-Content $archivoClave "Clave de administración (Historial y Configuración) de https://$Dominio`r`n$ClaveAdmin`r`n`r`nEstá en firma-api/.env como ADMIN_CLAVE. Guárdela en un lugar seguro y borre este archivo." -Encoding UTF8

Write-Host "`nPaquete listo: $zip ($([math]::Round((Get-Item $zip).Length / 1MB, 1)) MB)" -ForegroundColor Green
Write-Host "Clave de administración guardada en: $archivoClave" -ForegroundColor Yellow
Write-Host "Carpeta sin comprimir (para revisar o probar): $trabajo"
Write-Host 'Siga despliegue\cpanel\LEEME.md para subirlo.' -ForegroundColor Yellow
