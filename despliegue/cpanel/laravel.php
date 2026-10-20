<?php

/*
 * Controlador frontal de la API (Laravel) publicado en https://<dominio>/api.
 * El .htaccess envía aquí todas las rutas /api/*; el código de Laravel vive FUERA de la
 * carpeta pública (por defecto en ../firma-api), así .env, la base de datos y los PDFs
 * nunca son accesibles desde la web.
 */

use Illuminate\Http\Request;

define('LARAVEL_START', microtime(true));

$api = getenv('FIRMA_API_PATH') ?: dirname(__DIR__) . '/firma-api';

if (! is_file($api . '/vendor/autoload.php')) {
    http_response_code(503);
    header('Content-Type: application/json');
    echo json_encode(['message' => 'El servicio no está disponible en este momento.']);
    exit;
}

if (is_file($mantenimiento = $api . '/storage/framework/maintenance.php')) {
    require $mantenimiento;
}

require $api . '/vendor/autoload.php';

/** @var \Illuminate\Foundation\Application $app */
$app = require_once $api . '/bootstrap/app.php';
$app->usePublicPath(__DIR__);
$app->handleRequest(Request::capture());
