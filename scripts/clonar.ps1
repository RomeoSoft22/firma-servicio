# Clona los repositorios del sistema junto a firma-servicio (en la carpeta padre).
# Uso: .\firma-servicio\scripts\clonar.ps1
$ErrorActionPreference = 'Stop'
$base = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

foreach ($repo in 'firma-agente', 'firma-api', 'firma-web') {
    $destino = Join-Path $base $repo
    if (Test-Path $destino) {
        Write-Host "$repo ya existe: se actualiza con git pull" -ForegroundColor Yellow
        git -C $destino pull --ff-only
    } else {
        git clone "https://github.com/RomeoSoft22/$repo.git" $destino
    }
}
Write-Host "`nListo. Siguiente paso: .\firma-servicio\scripts\instalar.ps1" -ForegroundColor Green
