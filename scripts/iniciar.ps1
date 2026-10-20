# Arranca agente, API y front, cada uno en su propia ventana de PowerShell.
# Cierre una ventana para detener ese componente.
$ErrorActionPreference = 'Stop'
$base = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

$componentes = @(
    @{ Nombre = 'Agente de firma (127.0.0.1:9876)'; Carpeta = 'firma-agente'; Comando = 'dotnet run' },
    @{ Nombre = 'API (127.0.0.1:8000)'; Carpeta = 'firma-api'; Comando = 'php artisan serve --host=127.0.0.1 --port=8000' },
    @{ Nombre = 'Front (localhost:4200)'; Carpeta = 'firma-web'; Comando = 'npm start' }
)

foreach ($c in $componentes) {
    $ruta = Join-Path $base $c.Carpeta
    if (-not (Test-Path $ruta)) { throw "No existe $ruta. Ejecute primero scripts\clonar.ps1" }
    $titulo = "`$Host.UI.RawUI.WindowTitle = '$($c.Nombre)'"
    Start-Process powershell -WorkingDirectory $ruta -ArgumentList '-NoExit', '-Command', "$titulo; $($c.Comando)"
    Write-Host "Iniciado: $($c.Nombre)" -ForegroundColor Green
}
Write-Host "`nAbra http://localhost:4200 cuando el front termine de compilar." -ForegroundColor Cyan
