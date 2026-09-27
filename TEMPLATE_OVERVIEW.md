# Roundcube Webmail — One-Click Railway Template

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/siITGk)

**Roundcube webmail with Postgres — bring your own IMAP/SMTP provider.**

Roundcube is the classic open-source webmail client: a fast, skinable,
plugin-rich browser interface for any IMAP mailbox. This template provisions
Roundcube plus a Postgres database on Railway in one click, pre-wired to the
mail provider of your choice (Gmail by default).

**Scope note (important):** Roundcube is a webmail *client*, not a mail
server. It does not host mailboxes, accept MX delivery, or manage accounts —
it connects to an existing IMAP/SMTP provider (Gmail, Fastmail, Mailgun, your
own Dovecot/Postfix/Zimbra host, etc.). Every user signs in with their
**mail-server credentials**; there is no admin account by design.

## What you get

| Service | What it runs | Purpose |
|---|---|---|
| `roundcube` | `roundcube/roundcubemail:1.7.4-apache` (pinned), built from this repo's Dockerfile | The webmail UI on your Railway domain (port 80) |
| `Postgres` | Railway Postgres plugin | Settings, address book, identities, sessions |

**Zero deploy-form prompts** — everything is preconfigured:

- Postgres coordinates are wired automatically via Railway expressions
  (`ROUNDCUBEMAIL_DB_HOST/USER/PASSWORD/NAME` → the Postgres service; the DB
  password is generated per deployment).
- Mail provider defaults are baked in and overridable as plain service
  variables after deploy: `ROUNDCUBEMAIL_DEFAULT_HOST` (IMAP,
  `ssl://imap.gmail.com`), `ROUNDCUBEMAIL_DEFAULT_PORT` (993),
  `ROUNDCUBEMAIL_SMTP_SERVER` (SMTP, `tls://smtp.gmail.com`),
  `ROUNDCUBEMAIL_SMTP_PORT` (587).
- Plugins enabled: `archive` (one-click archiving), `zipdownload` (download
  messages/attachments as zip), `enigma` (OpenPGP sign/encrypt — keys persist
  on the `/var/roundcube/enigma` volume).
- First boot waits up to 120 s for Postgres, creates the schema
  automatically, and serves a static `/health.php` endpoint.

## Deploy

1. Click **Deploy on Railway**.
2. The `roundcube` service needs **no input**. If the form lists the Postgres
   plugin's internal variables, keep the standard values:
   `PGDATA=/var/lib/postgresql/data/pgdata`, `POSTGRES_USER=postgres`,
   `POSTGRES_DB=railway`, `PGPORT=5432`, `SSL_CERT_DAYS=820`,
   `RAILWAY_DEPLOYMENT_DRAINING_SECONDS=60`.
3. Wait ~2 minutes — both services go healthy, the DB schema initializes on
   first boot (Postgres first init can take ~1–2 minutes; one or two
   automatic restarts of roundcube are normal).
4. Open the `roundcube` domain and log in with your **mail credentials**:

| Provider | Username field | Notes |
|---|---|---|
| Gmail / Workspace | full address (`you@gmail.com`) | Google requires an **App Password** (2FA on) or Workspace with IMAP enabled |
| Fastmail / Mailgun IMAP / Zimbra | as your provider documents | Override the four `ROUNDCUBEMAIL_*` host/port variables to match |
| Self-hosted Dovecot/Postfix | as configured | Point the IMAP/SMTP variables at your host with `ssl://` or `tls://` prefixes |

## Troubleshooting

- **"Login failed" with a correct password** — wrong IMAP host/port or TLS
  prefix (IMAPS = `ssl://` + 993; STARTTLS = `tls://` + 143/587), or the
  provider needs an App Password.
- **Mail reads but won't send** — check `ROUNDCUBEMAIL_SMTP_SERVER`/`_PORT`;
  port 465 needs `ssl://`, port 587 uses `tls://`.
- **A few restarts on the very first deploy** — the container waits up to
  120 s for Postgres and exits once if it is slower; the ON_FAILURE policy
  retries automatically.

# Deploy and Host

## About Hosting

Hosting Roundcube on Railway means the webmail client runs as a containerized
Apache/PHP service while a managed Postgres holds settings, contacts, and
sessions. The template provisions exactly two services: `roundcube` (built
from the pinned `roundcube/roundcubemail:1.7.4-apache` image with a thin
Railway wrapper) and the `Postgres` database plugin. Mail itself stays at your
IMAP/SMTP provider, so there are no deliverability, PTR/DNS, or IP-reputation
concerns to manage. The deploy form has no prompts: the database connection is
injected through Railway variable expressions and the Postgres password is
generated fresh per deployment. The database schema is created and migrated
automatically on every boot (`bin/initdb.sh --update`), and PGP keys from the
enigma plugin persist on a dedicated volume.

## Why Deploy

- **One click, zero forms** — services, variables, domain, and volume are all
  preconfigured; nothing to type at deploy time.
- **Bring your own mail** — works with any IMAP/SMTP provider, so you keep
  your existing addresses and mail history; switch providers by changing four
  variables.
- **No mail-server headaches** — you get the webmail UX without running an
  MTA: no MX records, no spam-list risk, no TLS certificate juggling for
  mail.
- **Current and pinned** — Roundcube 1.7.4 (new layout, PHP 8.4) pinned so
  upgrades are your decision.
- **Operational niceties** — `/health.php` health endpoint, schema
  auto-migration on boot, restart policy that rides out a cold database, and
  PGP keys that survive redeploys.

## Common Use Cases

- A browser-based reader for a personal Gmail or Fastmail mailbox on your own
  domain.
- A self-hosted webmail front end for a company or family mail server
  (Dovecot/Postfix, Zimbra, hMailServer).
- Webmail for transactional-email teams who want to check an IMAP support or
  reply-to inbox without a desktop client.
- A privacy-conscious alternative to provider webmail: your own UI, your own
  hosting, any backend.
- A demo/testing client for mail infrastructure work (multiple providers,
  new accounts, deliverability checks).

## Dependencies for

Roundcube needs an external IMAP/SMTP mail provider to be useful — that is
the one thing you supply after deploy (mail credentials at the login screen).
Everything else is included.

### Deployment Dependencies

- **Postgres** — provisioned automatically by this template (Railway database
  plugin, schema auto-created on first boot; no action needed).
- **IMAP + SMTP provider** — Gmail (default config), Fastmail, Mailgun,
  Zimbra, or your own mail host. Override
  `ROUNDCUBEMAIL_DEFAULT_HOST`, `ROUNDCUBEMAIL_DEFAULT_PORT`,
  `ROUNDCUBEMAIL_SMTP_SERVER`, `ROUNDCUBEMAIL_SMTP_PORT` on the `roundcube`
  service if not using Gmail.
- **An App Password** for Gmail specifically (plain account passwords are
  rejected by Google's IMAP/SMTP endpoints).
