<?php
/**
 * Static Railway health endpoint for Roundcube.
 *
 * Roundcube 1.7 serves from /var/www/html/public_html and has no
 * unauthenticated JSON/health route; the login page also depends on the
 * database being initialized. This file is materialized at every boot by the
 * post-setup entrypoint hook and is intentionally dependency-free so the
 * platform healthcheck (and humans) can verify the web server is serving.
 */

header('Content-Type: text/plain; charset=utf-8');
header('Cache-Control: no-store');
http_response_code(200);
echo "OK - Roundcube webmail is serving\n";
