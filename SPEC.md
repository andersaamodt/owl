# Owl — Rust v1 Implementation Spec

*A file-first mail system implemented as a single Rust binary. No DB. Windows-safe filenames. Syncthing-friendly. Deployable to Raspberry Pi. Built with test-driven development (100% unit test coverage) and GitHub Actions CI producing ready binaries.*

---

## 0) Goals

* Deterministic, safe daemon/CLI.
* **100% unit test coverage** (crate level).
* **Push → GitHub Actions → downloadable binaries** for Pi (AArch64/ARMv7) and x86_64.
* File layout and behaviors exactly as below.

---

## 1) On-Disk Layout

```
/home/pi/mail/
  .env

  quarantine/                       # no .rules / .settings
    <sender>/                       # e.g., alice@example.org/
      <Subject slug> (<ULID>).eml
      .<Subject slug> (<ULID>).yml
      .<Subject slug> (<ULID>).html

  accepted/
    .rules
    .settings
    attachments/                    # content-addressed blobs
    <sender>/…

  spam/
    .rules
    .settings
    attachments/
    <sender>/…

  banned/
    .rules
    .settings
    attachments/
    <sender>/…

  drafts/
    <ULID>.md                       # YAML front-matter + Markdown body (autosave)

  outbox/
    <ULID>.eml
    .<ULID>.yml

  sent/
    <ULID>.eml                      # moved here on success
    .<ULID>.yml

  logs/                             # if logging != off
```

**Sender folder**: `local@domain` (lowercased, domain punycoded, `+tag` stripped unless `keep_plus_tags=true`).
**Message filename**: subject slug (Unicode preserved, whitespace collapsed, ≤80 chars, fallback `no subject`) + `(<ULID>).eml`.
**Attachments**: per-list `attachments/<sha256>__<orig-name>`; GC on delete.

---

## 2) Routing & Lists

* **Precedence**: banned → spam → accepted → quarantine.
* **`.rules`**: one per line:

  * `local@domain.tld`
  * `@example.org` (matches subdomains)
  * `@=example.org` (exact domain only)
  * `/…/` (POSIX ERE regex)
* **`.settings`**:

  ```
  list_status=accepted|rejected|banned
  delete_after=never|30d|6m|2y
  from=Your Name <you@example.org>
  reply_to=
  signature=~/.signatures/personal.txt
  body_format=both|plain|html
  collapse_signatures=true
  ```
* **Quarantine**: no `.rules` or `.settings`.

---

## 3) Sidecar YAML Schema

```yaml
schema: 1
ulid: "01J9P9…"
filename: "Subject (…) (01J9P9…).eml"
status_shadow: "accepted"
read: false
starred: false
pinned: false

hash_sha256: "…"
received_at: "2025-09-17T06:12:33Z"
last_activity: "2025-09-17T06:12:33Z"

render:
  mode: "strict"
  html: ".Subject (…) (01J9P9…).html"

attachments:
  - sha256: "ab12…"
    name: "invoice.pdf"

headers_cache:
  from: "Alice <alice@example.org>"
  to: ["you@example.org"]
  cc: []
  subject: "Hello"
  date: "Tue, 16 Sep 2025 23:12:33 -0700"

history: []    # only if logging = verbose
```

---

## 4) Pipelines

### Inbound

* Postfix receives on port 25 with STARTTLS (Let’s Encrypt).
* Rspamd scores (only displayed in Quarantine).
* Oversize reject at SMTP:

  * Quarantine cap 25M.
  * Approved cap 50M (default; `.env` configurable).
* Routing via `.rules`.
* Delivery: write `.eml`, sidecar `.yml`, sanitized `.html`, extract attachments.

### Outbound

* Drafts = `.md` with YAML front-matter (autosave).
* On send: render multipart/alt (default `both`), DKIM sign, queue `.eml` in `outbox/` with `.yml`.
* Retries: indefinite with backoff.
* On success: **move** `.eml`+`.yml` to `sent/`.
* On permanent fail: mark failed but keep in Outbox for manual resend.

---

## 5) Rendering & Security

* **Sanitization**: via external `sanitize-html` (Node).
* **HTML display**: sandboxed iframe + strict CSP.
* **Remote content**: blocked; click-to-load.
* **Plaintext**: generated via `lynx -dump`.
* **Render mode**: `strict|moderate` in `.env`.

---

## 6) Daemons & Triggers

* File watch (`inotify`) on `quarantine/` and `outbox/` for quick action.
* Cron every minute for reconciliation (retention, attachment GC).
* `.rules` reload only on `owl reload`.

---

## 7) Retention & Deletion

* Per-list `delete_after` (anchored on `last_activity`).
* Hard delete only: remove `.eml`, `.yml`, `.html`.
* Attachments garbage-collected if unreferenced.

---

## 8) Logging

* Levels: `off | minimal | verbose_sanitized | verbose_full`. Default = minimal.
* Outbox retries: one log line per attempt (if logging enabled).
* Logs: `/home/pi/mail/logs/`, umask 077.

---

## 9) CLI (human by default; `--json` for scripts)

```
owl install
owl update
owl restart [all|postfix|daemons]       # bare 'owl restart' == all
owl reload
owl triage [--address A|--list L]
owl list senders [--list L]
owl move-sender <from> <to> <address>
owl pin <address> [--unset]
owl send <draft.md|ULID>
owl backup /path
owl export-sender <list> <address> /path
owl import <maildir|mbox|tar.gz>
owl logs [tail|show]
```

---

## 10) Rust Crate Layout

```
src/
  main.rs
  cli.rs
  envcfg.rs
  model/
    message.rs
    rules.rs
    settings.rs
    address.rs
    filename.rs
  fsops/
    layout.rs
    io_atom.rs
    attach.rs
  pipeline/
    smtp_in.rs
    inbound.rs
    render.rs
    outbox.rs
    reconcile.rs
  ruleset/
    loader.rs
    eval.rs
  util/
    time.rs
    ulid.rs
    idna.rs
    logging.rs
    regex.rs
tests/
  integration/
    inbox_flow.rs
    routing.rs
    retention.rs
    outbox_retry.rs
    dkim_signing.rs
    import_export.rs
```

---

## 11) Dependencies

* **Core:** `clap`, `anyhow`, `thiserror`, `serde`, `serde_yaml`, `ulid`, `idna`, `time`, `walkdir`, `fs2`, `notify`, `regex`, `tempfile`, `duct`.
* **Mail:** `lettre`, `mailparse`, `ring`, `sha2`, `base64`.
* **Testing:** `proptest`, `assert_cmd`, `predicates`, `insta`, `mockall`.

---

## 12) Testing (100% unit coverage)

* **Unit (100%)**: address canonicalization, slugify, rules parsing/matching, settings/env parsers, sidecar YAML round-trip, attachment store, time helpers.
* **Property tests**: address idempotence, slug safety, rules precedence determinism.
* **Integration**: inbound delivery, outbox retries, retention GC, move-sender merge, import/export.
* **Golden tests**: snapshot YAML and rules parsing.
* **Coverage enforcement**: `cargo tarpaulin --fail-under 100`.

---

## 13) DKIM & SMTP

* DKIM selector = `mail`. Keys generated in `owl install`.
* Signing via `ring` or DKIM crate, tested against RFC vectors.
* SMTP send via `lettre`; backoff controlled by `.env`.

---

## 14) GitHub Actions CI

* **Jobs**:

  1. **Test & coverage**: cargo test + tarpaulin (fail if <100%).
  2. **Lint**: clippy + fmt.
  3. **Build**: cross-compile release binaries for x86_64-musl, aarch64-musl, armv7-gnueabihf.
  4. **Release**: on tag, upload artifacts to GitHub Release.

Artifacts named `owl-${target}`, plus `.sha256` checksums.

---

## 15) `.env` Starter

```ini
dmarc_policy=none
dkim_selector=mail
letsencrypt_method=http
keep_plus_tags=false

max_size_quarantine=25M
max_size_approved_default=50M

contacts_dir=/home/pi/contacts

logging=minimal
render_mode=strict
load_external_per_message=true

retry_backoff=1m,5m,15m,1h
```

---

## 16) Security & Ops

* TLS via Let’s Encrypt (HTTP-01).
* Rspamd enabled.
* Inbound rate limiting per-IP.
* Umask 077; atomic writes.
* chrony for timekeeping.

---

## 17) Milestones

1. **M1 Routing/Storage** — core models, address/rules/settings, sidecar schema, inbound stub.
2. **M2 Outbox/DKIM** — drafts→eml, sign, queue, retries, send→sent.
3. **M3 Retention/Attachments** — GC, delete_after enforcement.
4. **M4 Install/CI** — bootstrap script, DKIM/TLS setup, GitHub Actions green, binaries on release.

---

## 18) Deliverables

* Rust crate (`owl`).
* CI pipeline producing **Pi-ready static binaries**.
* 100% unit test coverage enforced.
* `SPEC.md` (this doc), README, starter `.env`.
