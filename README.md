# Firma Digital Web (réplica web de AppFirmaONPE)

Sistema de firma digital de PDF (PAdES) que funciona desde el navegador y usa el certificado
del usuario (token, DNIe o certificado instalado en Windows). Este repositorio reúne la
documentación general y los scripts para clonar y arrancar el sistema. Se compone de tres piezas:

| Repositorio | Componente |
| --- | --- |
| [firma-web](https://github.com/RomeoSoft22/firma-web) | Front Angular |
| [firma-api](https://github.com/RomeoSoft22/firma-api) | API Laravel |
| [firma-agente](https://github.com/RomeoSoft22/firma-agente) | Agente local .NET (certificados y firma) |

```
┌──────────────────────┐   HTTP (localhost)   ┌──────────────────────────┐
│  Front Angular       │ ───────────────────▶ │  Agente local (.NET 8)    │──▶ Almacén de Windows
│  http://localhost:4200│   certificados,     │  http://127.0.0.1:9876    │    token / DNIe (PIN)
│                      │   firmar, verificar  │  iText 7 · PAdES · TSA    │
└─────────┬────────────┘                      └──────────────────────────┘
          │ HTTP (PDF original y firmado, metadatos)
          ▼
┌──────────────────────┐
│  API Laravel         │  historial, lotes de firma masiva, motivos, parámetros (SQLite)
│  http://127.0.0.1:8000│  — nunca recibe ni maneja claves privadas
└──────────────────────┘
```

**Por qué hay un agente local:** un navegador no puede acceder al almacén de certificados ni al
token/smartcard. El agente es un pequeño servicio que escucha **solo en 127.0.0.1**, acepta
peticiones únicamente de los orígenes configurados y realiza la operación con la clave privada.
La clave nunca sale del token: Windows muestra el diálogo de PIN cuando corresponde.

## Equivalencias con AppFirmaONPE

| AppFirmaONPE (escritorio)                                  | Este sistema |
| ---------------------------------------------------------- | ------------ |
| `ServiceFirma.SeleccionarCertificado`, `ServiceParceX509ToCertBean`, `ValidarCertificado.paraFirmaDigital`, `CertificadoBean` | Agente: `CertificadoService` · `GET /api/certificados` · Front: selector de certificado |
| `ServiceFirma2.SignHashed / SignDetached / SignMsg`         | Agente: `FirmaWindows` (`IExternalSignature` sobre la clave de Windows) |
| `ServiceFirma.FirmarPDFitext / FirmarContenidoV2 / firmarPdf` | Agente: `PdfFirmaService` · `POST /api/firmar` |
| `PosicionFirmaService`, `MotivoBean`                        | Front: visor pdf.js con recuadro arrastrable + opciones · Agente: posiciones por esquina |
| `ServiceTsa.GetTimeStampToken` (RFC 3161)                   | Agente: `TSAClientBouncyCastle` (opción «sello de tiempo») |
| `ServiceFirma.FirmarPDFOcsp`, `CrlBean`                     | Agente: OCSP + CRL incrustados (opción «LTV») |
| `ServiceValidationSignedDoc`                                | Agente: `PdfVerificacionService` · `POST /api/verificar` · Front: «Verificar firma» |
| `ServiceFirmaMasiva`, `ServiceFirmaCarpeta`                 | Front: «Firma masiva» (archivos del navegador) · Agente: `POST /api/firmar-carpeta` |
| `Connection` (XML), `ServiceParametro`                      | API: tabla `parametros` y `motivos` · Front: «Configuración» |

## Requisitos

| Pieza  | Requisitos |
| ------ | ---------- |
| Front  | Node.js 20+ |
| Agente | Windows 10/11, [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) (solo para compilar; el .exe publicado es autocontenido) y el middleware/minidriver del token o DNIe |
| API    | PHP 8.2+ (`pdo_sqlite`, `fileinfo`, `mbstring`, `openssl`) y Composer |

Con winget:

```powershell
winget install Microsoft.DotNet.SDK.8
winget install PHP.PHP.8.3
```

Notas de instalación en Windows:

- **php.ini:** el paquete de winget no trae `php.ini`. Copie `php.ini-development` a `php.ini` en la carpeta
  de PHP y habilite `extension_dir = "ext"` y las extensiones `openssl`, `pdo_sqlite`, `sqlite3`,
  `fileinfo`, `mbstring`, `curl`, `zip`, `intl`. Suba `upload_max_filesize`/`post_max_size` (p. ej. 200M).
- **Composer** no está en winget: use el instalador oficial de https://getcomposer.org/download/.
- **Rutas largas:** Dart Sass (usado por Angular) falla si la carpeta del proyecto tiene una ruta muy
  larga. Ubique el proyecto en una ruta corta (p. ej. `C:\proyectos\firma-digital`).

## Puesta en marcha rápida

En una carpeta de ruta corta (p. ej. `C:\proyectos\firma-digital`):

```powershell
git clone https://github.com/RomeoSoft22/firma-servicio.git
.\firma-servicio\scripts\clonar.ps1      # clona firma-agente, firma-api y firma-web al lado
.\firma-servicio\scripts\instalar.ps1    # dependencias, .env, base de datos (solo la primera vez)
.\firma-servicio\scripts\iniciar.ps1     # abre agente, API y front, cada uno en su ventana
```

Luego abra http://localhost:4200.

## Puesta en marcha manual

### 1. Agente local ([firma-agente](https://github.com/RomeoSoft22/firma-agente))

```powershell
cd firma-agente
dotnet run
# o un único ejecutable para distribuir a los usuarios:
dotnet publish -c Release   # → bin\Release\net8.0-windows\win-x64\publish\AgenteFirma.exe
```

Configuración en `appsettings.json` (puerto, orígenes permitidos, tamaño máximo, TSA por defecto).
Si publica el front en otro dominio, agréguelo a `OrigenesPermitidos`.

Debe ejecutarse **en la sesión del usuario** (no como servicio de Windows), para que pueda ver su
almacén personal y mostrar el diálogo de PIN.

### 2. API Laravel ([firma-api](https://github.com/RomeoSoft22/firma-api))

```powershell
cd firma-api
composer install
copy .env.example .env    # ajuste APP_ENV=production, APP_DEBUG=false, APP_LOCALE=es, CORS_ORIGINS
php artisan key:generate
php artisan migrate --seed
php artisan serve --host=127.0.0.1 --port=8000
```

### 3. Front Angular ([firma-web](https://github.com/RomeoSoft22/firma-web))

```powershell
cd firma-web
npm install
npm start          # http://localhost:4200
```

## Endpoints

**Agente** (`http://127.0.0.1:9876/api`)

| Método | Ruta | Descripción |
| ------ | ---- | ----------- |
| GET  | `/estado` | Versión y equipo |
| GET  | `/certificados?todos=false` | Certificados del almacén personal (aptos para firma, o todos) |
| POST | `/firmar` | `{ thumbprint, pdfBase64, nombreArchivo, opciones }` → PDF firmado en base64 |
| POST | `/firmar-carpeta` | `{ thumbprint, carpetaOrigen, carpetaDestino?, sufijo, recursivo, opciones }` |
| POST | `/verificar` | `{ pdfBase64 }` → firmas, integridad, sello de tiempo, vigencia |

**API** (`http://127.0.0.1:8000/api`)

| Método | Ruta | Descripción |
| ------ | ---- | ----------- |
| GET/POST | `/documentos` | Listar (filtros `q`, `estado`, `lote_id`) / subir PDF original |
| GET/DELETE | `/documentos/{id}` | Detalle / eliminar |
| POST | `/documentos/{id}/firmado` | Adjuntar PDF firmado + datos del firmante |
| POST | `/documentos/{id}/error` | Registrar un error de firma |
| GET  | `/documentos/{id}/descargar/{original\|firmado}` | Descarga |
| GET  | `/documentos/hash/{sha256}` | Comprobar si un PDF firmado fue emitido por el sistema |
| GET  | `/documentos/estadisticas` | Totales |
| GET/POST | `/lotes`, GET `/lotes/{id}` | Lotes de firma masiva |
| GET/POST/PUT/DELETE | `/motivos` | Catálogo de motivos, con tamaño (`ancho`, `alto`; vacío = el de Parámetros) y diseño del sello (`disposicion`: `horizontal` = imagen a la izquierda, `vertical` = imagen arriba). DELETE es borrado lógico y nunca puede quedar sin motivos activos (422). |
| GET/POST/DELETE | `/motivos/{id}/imagen` | Imagen del sello de cada motivo (PNG/JPG, máx. 1 MB) |
| GET/PUT | `/parametros` | TSA, lugar, motivo por defecto, tamaño del sello, etc. |

## Seguridad

Medidas aplicadas (verificadas con peticiones directas):

| Componente | Medida |
| ---------- | ------ |
| Front | Los mensajes al usuario no mencionan tecnologías ni detalles internos; los errores 5xx se muestran como un mensaje genérico. |
| API | `APP_DEBUG=false` y `APP_ENV=production`: sin trazas ni nombres de excepción. Las excepciones HTTP (404 de modelo, 405, 429…) devuelven textos genéricos, sin nombres de clases. |
| API | Sin cabecera `X-Powered-By` (`expose_php = Off` en php.ini y middleware); sin página de bienvenida ni `/up`. |
| API | Cabeceras `X-Content-Type-Options`, `X-Frame-Options: DENY`, `Referrer-Policy`, `Permissions-Policy` y `Content-Security-Policy: default-src 'none'`. |
| API | Límite de 300 peticiones/minuto por IP; parámetros de ruta restringidos (IDs numéricos, hash hexadecimal de 64, tipo `original\|firmado`). |
| API | Archivos en almacenamiento privado (fuera de `public/`), validados por contenido (PDF; PNG/JPG ≤ 1 MB y ≤ 2000×2000 px); la ruta interna nunca se expone. CORS restringido a los orígenes del front. |
| Agente | Solo escucha en 127.0.0.1. `AllowedHosts` bloquea ataques de DNS rebinding. Exige un `Origin` de la lista blanca en cada petición (403 si no). |
| Agente | Sin cabecera `Server`. Los errores devuelven mensajes para el usuario; el detalle técnico queda solo en el log local. Ya no expone el usuario de Windows. |

### Pendientes antes de producción

- **Autenticación:** la API no tiene inicio de sesión (hoy solo escucha en 127.0.0.1). Si se publica en
  red para varios usuarios, agregue login (p. ej. Laravel Sanctum) y asocie cada documento a su usuario.
- **HTTPS:** al publicar el front y la API en un servidor, sírvalos por HTTPS y agregue `Strict-Transport-Security`
  y una `Content-Security-Policy` en el servidor web del front.
- **Agente:** `firmar-carpeta` lee y escribe en disco; mantenga `OrigenesPermitidos` restringido a su dominio.
- **Cadena de confianza:** la verificación comprueba integridad, vigencia y sello de tiempo. Validar
  contra la TSL de INDECOPI / IOFE (equivalente a `TslBean`) queda pendiente: requiere cargar los
  certificados raíz acreditados.
- **Tokens antiguos:** algunos tokens con CSP heredado no admiten SHA-256; se recomienda el minidriver
  actual del fabricante.
- **Licencia de iText 7:** AGPL. Para uso cerrado/comercial se requiere licencia comercial o
  reemplazarlo (p. ej. por PdfSharp + BouncyCastle).
- **Firma en servidor (HSM):** la alternativa descrita en el análisis no está implementada; solo
  aplica si la institución tiene potestad sobre las claves.
