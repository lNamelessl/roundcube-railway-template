# Roundcube webmail on Railway — thin wrapper over the official image.
# Base: roundcube/roundcubemail 1.7.4, apache variant
# (Debian, PHP 8.4, Apache listening on port 80; the entrypoint runs as root
# and the stock nonroot stage that listens on 8000 is NOT what we build).
FROM roundcube/roundcubemail:1.7.4-apache

# Railway platform fix: the 1.7.4-apache image ships BOTH mpm_event and
# mpm_prefork enabled, which kills Apache at boot with
# "AH00534: apache2: Configuration error: More than one MPM loaded".
# (a2dismod turned out unreliable here — it silently left mpm_event enabled —
# so remove the module links directly.) Keep exactly one MPM: prefork, the
# mod_php requirement (php.load is enabled).
RUN rm -f /etc/apache2/mods-enabled/mpm_event.load /etc/apache2/mods-enabled/mpm_event.conf \
        /etc/apache2/mods-enabled/mpm_worker.load /etc/apache2/mods-enabled/mpm_worker.conf; \
    ln -sf ../mods-available/mpm_prefork.load /etc/apache2/mods-enabled/mpm_prefork.load; \
    ln -sf ../mods-available/mpm_prefork.conf /etc/apache2/mods-enabled/mpm_prefork.conf; \
    echo "MPM modules enabled after fix:"; ls /etc/apache2/mods-enabled/ | grep mpm

# Static defaults baked into the image so the published Railway template stays
# zero-prompt (literal service variables would surface as deploy-form prompts).
# Only the per-deploy Postgres coordinates (ROUNDCUBEMAIL_DB_HOST / _USER /
# _PASSWORD / _NAME) are NOT baked — those are Railway expression variables
# referencing the Postgres service.
#
# IMAP host and SMTP server accept tls:// / ssl:// prefixes; host and port are
# concatenated by the image entrypoint into imap_host / smtp_host, e.g.
#   ROUNDCUBEMAIL_DEFAULT_HOST=ssl://imap.gmail.com + _PORT=993
#     -> imap_host = "ssl://imap.gmail.com:993"
#   ROUNDCUBEMAIL_SMTP_SERVER=tls://smtp.gmail.com + _PORT=587
#     -> smtp_host = "tls://smtp.gmail.com:587"
ENV ROUNDCUBEMAIL_DB_TYPE=pgsql \
    ROUNDCUBEMAIL_DB_PORT=5432 \
    ROUNDCUBEMAIL_DEFAULT_HOST=ssl://imap.gmail.com \
    ROUNDCUBEMAIL_DEFAULT_PORT=993 \
    ROUNDCUBEMAIL_SMTP_SERVER=tls://smtp.gmail.com \
    ROUNDCUBEMAIL_SMTP_PORT=587 \
    ROUNDCUBEMAIL_PLUGINS=archive,zipdownload,enigma

# 1) Pre-setup hook — runs at the very start of every boot, BEFORE the stock
#    entrypoint's own /wait-for-it.sh (hard-coded 30s). A cold Railway Postgres
#    (first provisioning, volume restore) can take longer than 30s, and the
#    stock entrypoint does NOT abort when `bin/initdb.sh` fails — it logs and
#    starts Apache anyway, leaving a broken install. This hook waits up to
#    120s for the TCP port, then exits 1 so the container fails and the
#    ON_FAILURE restart policy retries.
COPY --chmod=755 railway-pre-setup.sh /entrypoint-tasks/pre-setup/00-railway-wait-db.sh

# 2) Post-setup hook — runs at the END of every boot, AFTER the entrypoint has
#    populated the docroot (a stray file baked into the docroot would trip the
#    entrypoint's "directory is not empty" 10-second warning) and BEFORE
#    `exec apache2-foreground`. It:
#      - materializes the static /health.php into BOTH docroots
#        (/var/www/html/ and /var/www/html/public_html/ — Roundcube 1.7 serves
#        from public_html; writing both keeps the probe layout-proof)
#      - makes the enigma volume (PGP keyring) writable by www-data, since
#        Railway mounts volumes as root:root
COPY --chmod=755 railway-post-setup.sh /entrypoint-tasks/post-setup/00-railway-health.sh
COPY health.php /railway-health.php

# The root-stage image exposes nothing (only the unused nonroot stage exposes
# 8000). Declare 80 so Railway's port detection and humans agree.
EXPOSE 80
