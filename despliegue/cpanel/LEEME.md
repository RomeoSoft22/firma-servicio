# Despliegue en cPanel — firma.juarezcampos.net

El paquete `firma-cpanel-<dominio>-<fecha>.zip` (generado con `scripts\empaquetar-cpanel.ps1`)
contiene dos carpetas:

| Carpeta | Destino en el hosting | Contenido |
| --- | --- | --- |
| `firma.juarezcampos.net/` | Raíz del subdominio (pública) | SPA Angular, `.htaccess`, `laravel.php`, `descargas/AgenteFirmaSetup.exe` |
| `firma-api/` | **Fuera** de la web, junto a la anterior | Laravel con `vendor/`, `.env` de producción y base SQLite ya creada |

> El `.zip` incluye el `.env` con la clave `APP_KEY` de la instalación: trátelo como confidencial
> y no lo suba a GitHub ni lo comparta.

## 1. Preparar el subdominio (una sola vez)

1. **cPanel → Dominios → Crear un nuevo dominio**: `firma.juarezcampos.net`.
   Raíz del documento: `/home/USUARIO/firma.juarezcampos.net` (desmarque «Compartir la raíz con
   el dominio principal»). Si cPanel propone `public_html/firma.juarezcampos.net`, cámbielo: la
   carpeta `firma-api` debe quedar **al lado** de la raíz del subdominio y no dentro de `public_html`.
2. **cPanel → MultiPHP Manager**: seleccione el dominio y **PHP 8.3** (o superior).
3. **cPanel → Seleccionar versión de PHP → Extensiones**: active `pdo_sqlite`, `sqlite3`, `mbstring`,
   `fileinfo`, `openssl`, `curl`, `zip`, `intl`.
   **Opciones**: `upload_max_filesize = 200M`, `post_max_size = 210M`, `memory_limit = 512M`,
   `expose_php = Off`.
4. **cPanel → SSL/TLS Status → Run AutoSSL** para obtener el certificado HTTPS del subdominio.

## 2. Subir el paquete

1. **cPanel → Administrador de archivos** → vaya a `/home/USUARIO/` (la carpeta personal, no `public_html`).
2. **Cargar** el `.zip` y luego **Extraer** allí mismo. Quedará:
   ```
   /home/USUARIO/firma.juarezcampos.net/   (index.html, .htaccess, laravel.php, …)
   /home/USUARIO/firma-api/                (Laravel)
   ```
3. Permisos (normalmente ya son correctos): carpetas `755`, archivos `644`; PHP debe poder escribir en
   `firma-api/storage`, `firma-api/bootstrap/cache` y `firma-api/database`.
4. Borre el `.zip` del servidor.

> Si «Mostrar archivos ocultos» está desactivado no verá `.htaccess` ni `.env`, pero están ahí.

## 3. Comprobar

| Prueba | Resultado esperado |
| --- | --- |
| `https://firma.juarezcampos.net` | Abre la aplicación |
| `https://firma.juarezcampos.net/historial` y recargar (F5) | Sigue en Historial (no 404) |
| `https://firma.juarezcampos.net/api/estado` | `{"estado":"ok"}` |
| `https://firma.juarezcampos.net/.htaccess` | 403 Prohibido (archivos ocultos bloqueados) |
| `https://firma.juarezcampos.net/api/xyz` | `{"message":"El recurso solicitado no existe."}` sin datos del servidor |
| Configuración → Probar conexión | Agente y servicio de registro «conexión correcta» |

## 4. Puestos de firma (cada PC de usuario)

1. Desde la aplicación (aviso en «Firmar documento») o desde
   `https://firma.juarezcampos.net/descargas/AgenteFirmaSetup.exe`, descargue e instale el
   **Agente de Firma** (no pide administrador; queda en el menú Inicio y arranca al iniciar sesión).
2. Windows SmartScreen puede advertir «editor desconocido» porque el instalador no está firmado con un
   certificado de firma de código: «Más información → Ejecutar de todas formas».
3. La primera vez, Chrome/Edge pueden preguntar si **firma.juarezcampos.net puede acceder a
   dispositivos de la red local**: responda **Permitir** (es la comunicación con el agente de esa PC).
4. Conecte el token o DNIe y firme.

## Actualizar a una nueva versión

Genere un paquete nuevo y, en el hosting:

- Reemplace el contenido de `firma.juarezcampos.net/`.
- En `firma-api/` reemplace todo **excepto** `.env`, `database/database.sqlite` y `storage/`
  (ahí están la configuración, los datos y los PDFs). Si hay migraciones nuevas, ejecútelas desde
  **cPanel → Terminal**: `cd ~/firma-api && php artisan migrate --force`.

## Respaldo

Descargue periódicamente `firma-api/database/database.sqlite` y `firma-api/storage/app/private/`
(documentos originales y firmados, imágenes de los motivos).
