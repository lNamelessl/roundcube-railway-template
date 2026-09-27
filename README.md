# Roundcube Webmail — Railway Template

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.app/new/template/roundcube-template)

Roundcube — the classic open-source webmail client — pre-wired to a Postgres
backend on Railway, pointed at any IMAP/SMTP mail provider you choose
(Gmail, your own mail host, anything with IMAP + SMTP).

> **Scope: webmail client, not a mail server.** Roundcube reads and sends mail
> *through* an existing IMAP/SMTP provider. It does not host mailboxes. This
> template pairs it with Postgres (settings, contacts, sessions) and leaves the
> mail side to your provider.

## What you get

| Service | Image / source | Purpose |
|---|---|---|
| `roundcube` | `roundcube/roundcubemail:1.7.4-apache` (pinned) | The webmail UI, Apache on port 80 |
| `Postgres` | Railway database plugin | Settings, address book, sessions — schema auto-created on first boot |

**No admin login exists.** Roundcube has no administrator account: every user
signs in with their **mail-server credentials** (IMAP username/password). The
login screen is the first screen you see.

## Mail provider checklist (fill these in or keep the defaults)

The template ships with sensible Gmail defaults; all are overridable as service
variables on the `roundcube` service:

| Variable | Default (Gmail) | Notes |
|---|---|---|
| `ROUNDCUBEMAIL_DEFAULT_HOST` | `ssl://imap.gmail.com` | IMAP host; `ssl://` or `tls://` prefix supported |
| `ROUNDCUBEMAIL_DEFAULT_PORT` | `993` | IMAP port (993 = IMAPS) |
| `ROUNDCUBEMAIL_SMTP_SERVER` | `tls://smtp.gmail.com` | SMTP host; `tls://` or `ssl://` prefix supported |
| `ROUNDCUBEMAIL_SMTP_PORT` | `587` | SMTP submission port |
| `ROUNDCUBEMAIL_PLUGINS` | `archive,zipdownload,enigma` | `enigma` stores PGP keys on the volume |

The Postgres connection (`ROUNDCUBEMAIL_DB_HOST/USER/PASSWORD/NAME`) is wired
automatically via Railway expressions — nothing to fill in.

For Gmail specifically: logins need an **App Password** (2FA required) or a
Google Workspace domain with suitable auth policy — a plain account password
will be rejected by Google's IMAP/SMTP endpoints. Other providers (Fastmail,
Mailgun IMAP/SMTP add-on, self-hosted Dovecot/Postfix, Zimbra…) work with
their normal host/port/credentials.

## Included plugins

- `archive` — one-click folder archiving
- `zipdownload` — download messages/attachments as zip
- `enigma` — OpenPGP (sign/encrypt); keys persist on the
  `/var/roundcube/enigma` volume

## Deploy

1. Click the deploy button (or `railway deploy -t roundcube-template`).
2. Wait for both services to go healthy — Roundcube waits up to 120 s for
   Postgres and initializes the schema on first boot.
3. Open the `roundcube` domain. Log in with your mail credentials
   (`user@domain` for Gmail; some providers want just the local part — set
   `ROUNDCUBEMAIL_USERNAME_DOMAIN` if your provider expects `user` + a domain
   appended automatically).

## Health & operations

- `GET /health.php` — static, dependency-free 200 endpoint (platform
  healthcheck target).
- DB schema is created/updated on every boot (`bin/initdb.sh --update`);
  data persists in the Postgres service.
- PGP keys (enigma) persist on the `/var/roundcube/enigma` volume across
  redeploys.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Login failed` with correct password | Wrong IMAP host/port or TLS prefix (use `ssl://` + 993 for IMAPS, `tls://` + 587 for STARTTLS submission). Gmail: use an App Password. |
| Login works, sending fails | Check SMTP server/port (`tls://smtp.gmail.com:587`); some providers want port 465 (`ssl://`). |
| Provider logs show connection refused | Private networking: hosts are container-to-container; your mail provider must be reachable over the public internet — it is, since Roundcube egresses normally. |
| Roundcube restarts a few times on first deploy | The container waits up to 120 s for Postgres and exits once if it is slower; the ON_FAILURE policy retries. |

## Cost

Roughly **$5/mo** (Roundcube container ~512 MB + smallest Postgres). Roundcube
is lightweight; scale only if you share it with many users.

## Repository layout

```
├── Dockerfile              # thin wrapper over roundcube/roundcubemail:1.7.4-apache
├── health.php              # static health endpoint, materialized post-setup
├── railway-pre-setup.sh    # 120s Postgres wait hook (pre-setup)
├── railway-post-setup.sh   # health.php materialization + enigma chown (post-setup)
├── railway.json            # roundcube build/deploy config
└── postgres/railway.json   # Postgres deploy config
```
