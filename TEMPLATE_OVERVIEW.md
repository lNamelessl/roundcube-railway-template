# Template Overview — Roundcube Webmail on Railway

**Short description (≤75 chars):**
Roundcube webmail with Postgres — bring your own IMAP/SMTP provider

## Positioning

Roundcube is the classic open-source webmail client (99⭐ class demand in the
YunoHost gap scan; zero Railway presence). This template gives it a one-click
home on Railway with Postgres for settings/contacts/sessions, pointed at any
IMAP/SMTP provider the deployer already has.

**Scope disclosure (must stay in the listing):** Roundcube is a webmail
*client*, not a mail server. It does not host mailboxes or accept MX traffic;
users read/send through an external IMAP/SMTP provider (Gmail, Fastmail,
Mailgun, a self-hosted Dovecot/Postfix, etc.).

## What the template provisions

| Service | Source | Purpose |
|---|---|---|
| `roundcube` | Builds `Dockerfile` in this repo → `roundcube/roundcubemail:1.7.4-apache` | Webmail UI, Apache on port 80 |
| `Postgres` | Railway `postgres` database plugin | Settings, address book, sessions |

- Volume: `/var/roundcube/enigma` on the roundcube service (PGP keyring,
  persists across redeploys).
- Domain: HTTP domain on the roundcube service, target port 80.

## Variables (serializedConfig expectations)

`roundcube` service — expression-only, zero deploy-form prompts:

- `ROUNDCUBEMAIL_DB_HOST = ${{Postgres.PGHOST}}`
- `ROUNDCUBEMAIL_DB_USER = ${{Postgres.PGUSER}}`
- `ROUNDCUBEMAIL_DB_PASSWORD = ${{Postgres.PGPASSWORD}}`
- `ROUNDCUBEMAIL_DB_NAME = ${{Postgres.PGDATABASE}}`

Everything else (DB type/port, IMAP/SMTP defaults, plugins) is baked as ENV in
the Dockerfile — literals never appear as service variables, so the deploy form
has no prompts.

## Design decisions (verified against roundcubemail-docker 1.7.4)

1. **Port 80.** The `:apache` root stage listens on 80 (its `EXPOSE 8000` /
   `:8000` vhost belongs to the `-nonroot` variant we do not build). The
   domain pins targetPort 80.
2. **DB wait hook (pre-setup).** The stock entrypoint waits only 30 s
   (`/wait-for-it.sh -t 30`) and — worse — does not abort when schema init
   fails; it starts Apache anyway. `railway-pre-setup.sh` runs from the
   image's `/entrypoint-tasks/pre-setup/` hook dir, waits up to 120 s via
   PHP `fsockopen`, and exits 1 on timeout so ON_FAILURE restarts.
3. **Health endpoint (post-setup).** Roundcube 1.7 has no `/login` route
   (front controller only) and the stock image ships no health route.
   `railway-post-setup.sh` runs from `/entrypoint-tasks/post-setup/` on every
   boot and copies the static `health.php` into BOTH docroots
   (`/var/www/html/` and `/var/www/html/public_html/` — 1.7 serves the
   latter). It must be a runtime hook: the entrypoint tar-populates the
   docroot at boot and warns + sleeps 10 s if it is not empty.
   `railway.json` healthchecks `/health.php` (300 s timeout, ON_FAILURE × 10).
4. **Enigma volume ownership.** Railway mounts volumes root:root; the
   post-setup hook chowns `/var/roundcube/enigma` to www-data so PGP keys can
   be written.
5. **Zero admin login.** Users authenticate with their mail-server (IMAP)
   credentials; there is no admin account to seed.

## First-boot behavior

1. Entrypoint pre-setup hook waits for Postgres (≤120 s).
2. `bin/initdb.sh --dir=SQL --update` creates the schema on an empty DB,
   applies migrations on existing ones.
3. `config.docker.inc.php` regenerated from env on every boot (config is
   env-driven; nothing to edit by hand).
4. Post-setup hook writes `/health.php` into both docroots; Apache starts;
   healthcheck passes.

## Acceptance record

- `/health.php` → 200 on the deployed domain
- Postgres schema initialized (roundcube tables present, verified via psql)
- `/?_task=login` → 200, Roundcube login page renders
- `config.docker.inc.php` verified via `railway ssh` (imap_host/smtp_host/
  plugins/db_dsnw rendered from env)
- **Mail round-trip** via throwaway GreenMail service
  (`greenmail/standalone:2.1.14`, IMAP :3143 / SMTP :3025, private
  networking): scripted Roundcube login with `webmail@example.com` → compose +
  send through Roundcube's SMTP → message verified in the GreenMail inbox via
  its REST API. GreenMail removed after acceptance; defaults restored.
- Persistence: marker file on the enigma volume + Postgres rows survive a
  redeploy.
- 2/2 fresh deploys from the published template reach `200 /health.php`.
