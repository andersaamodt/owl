# Owl Documentation Overview

Owl is a file-first mail hub designed to run unattended on small Linux machines (e.g., Raspberry Pi) while remaining fully deterministic and transparent on disk. The Rust binaries provide all core behavior; no database or external server process is required beyond SMTP delivery and local tooling described below.

## Architecture at a Glance

- **Storage**: canonical tree rooted at `/home/pi/mail` with dedicated lists (accepted/spam/banned/quarantine), drafts, outbox, sent, and logs.
- **Sidecars**: every message has a YAML `.yml` metadata file that records delivery status, headers, attachment inventory, and retry history.
- **Pipelines**: inbound delivery parses mail, extracts attachments, sanitizes HTML, and files messages according to `.rules`; outbound delivery renders drafts, signs with DKIM, queues in `outbox/`, and retries until sent.
- **Daemon**: `owl-daemon` watches quarantine/outbox and enforces retention + garbage collection.

For the canonical layout and schema definitions, see `SPEC.md`.

## Runtime Components

### Mail layout

```
/home/pi/mail/
  quarantine/ accepted/ spam/ banned/
  drafts/ outbox/ sent/
  logs/
```

- **Sender folders** are normalized (lowercased, punycoded domains, optional `+tag` removal).
- **Message names** include a subject slug and ULID to ensure stable, collision-free files.
- **Attachments** are content-addressed under each list.

### Configuration

- `owl` reads `.env` for defaults and feature toggles; use `env.sample` as a starting point.
- `.rules` routes inbound mail by address, domain, or regex, with precedence: `banned → spam → accepted → quarantine`.
- `.settings` is per-list and overrides routing/list behavior and retention.

### Inbound flow (SMTP → delivery)

1. Accept mail via Postfix with Rspamd scoring.
2. Enforce size limits (quarantine vs. approved).
3. Route to list and persist `.eml` + `.yml` + sanitized `.html`.
4. Extract attachments and update sidecar metadata.

### Outbound flow (draft → sent)

1. Draft is a `.md` file with YAML front matter.
2. Render multipart/alternative (plain + HTML), apply DKIM signature.
3. Queue `.eml` + `.yml` in `outbox/` and retry until success.
4. Move to `sent/` on success; keep failed attempts for manual resend.

### Daemon responsibilities

- Watch quarantine/outbox for immediate processing.
- Enforce retention policies and garbage-collect orphaned attachments.
- Write structured logs in `/home/pi/mail/logs/` based on the configured log level.

## Testing & CI

- Unit and integration tests live in `src/` and `tests/integration/`.
- CI runs `cargo test`, `clippy`, `fmt`, and `cargo tarpaulin --fail-under 100`.

## Operations Notes

- `owl install` provisions DKIM keys, Postfix integration hooks, and other system markers.
- `owl update` reapplies provisioning safely.
- `owl reload` reloads routing rules without restarting the daemon.

For CLI usage details, see `docs/cli.md`.
