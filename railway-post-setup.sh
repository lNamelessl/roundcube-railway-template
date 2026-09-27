#!/bin/sh
# Railway post-setup hook: runs at the end of every boot, after the docroot is
# populated and before Apache starts. Runs as root (the apache variant starts
# as root to bind port 80).

# 1) Materialize the static health endpoint. Roundcube 1.7 has no /login route
#    without rewrites and its front controller redirects bare routes, so a
#    plain dependency-free PHP file is the reliable unauthenticated probe
#    target. Written into BOTH docroots: 1.7 serves /var/www/html/public_html,
#    older layouts served /var/www/html — this keeps the probe layout-proof.
cp /railway-health.php /var/www/html/public_html/health.php 2>/dev/null || true
cp /railway-health.php /var/www/html/health.php 2>/dev/null || true

# 2) The enigma plugin stores PGP keys in /var/roundcube/enigma. Railway
#    mounts volumes as root:root; Apache (www-data) needs write access.
mkdir -p /var/roundcube/enigma
chown -R www-data:www-data /var/roundcube/enigma 2>/dev/null || true

exit 0
