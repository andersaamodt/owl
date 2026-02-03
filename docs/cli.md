# Owl CLI Reference

The `owl` CLI is the primary interface for provisioning, triage, and maintenance. It is designed to be POSIX-shell friendly: exit status indicates success/failure, and `--json` provides machine-readable output for commands that return structured data.

## Global flags

- `--env <path>`: path to the `.env` file (defaults to `~/mail/.env`, tilde expands to home directory).
- `--json`: enable JSON output for supported commands (currently `triage` and `logs`).

## Commands

### `owl install`

Bootstrap mail storage, DKIM keys, and system hooks.

```
owl install
```

### `owl update`

Re-apply provisioning hooks and ensure layout exists.

```
owl update
```

### `owl restart [all|postfix|daemons]`

Restart Owl services via `systemctl`.

```
owl restart
owl restart postfix
```

### `owl reload`

Reload routing rules without restarting the daemon.

```
owl reload
```

### `owl configure`

Run the interactive configuration wizard for env settings, routing rules, and list defaults.

```
owl configure
owl configure --env /path/to/.env
```

### `owl triage [--address A] [--list L]`

List messages in quarantine (default) or a specific list.

```
owl triage
owl triage --list accepted
owl triage --address alice@example.org --list spam
```

JSON output:

```
owl triage --json
```

### `owl list senders [--list L]`

Show sender directories for one list or all lists.

```
owl list senders
owl list senders --list banned
```

### `owl move-sender <from> <to> <address>`

Move all mail for a sender between lists.

```
owl move-sender accepted spam alice@example.org
```

### `owl pin <address> [--unset]`

Toggle the pinned flag for all messages from a sender.

```
owl pin alice@example.org
owl pin alice@example.org --unset
```

### `owl send <draft.md|ULID>`

Queue a draft for delivery. Use a full path or an ULID stem.

```
owl send 01J9P9ABCDEF
```

### `owl backup /path`

Create a tarball of the mail root.

```
owl backup /tmp/owl-backup.tar
```

### `owl export-sender <list> <address> /path`

Export a single sender to a tarball.

```
owl export-sender accepted alice@example.org /tmp/alice.tar
```

### `owl import <maildir|mbox|tar.gz>`

Import legacy archives into quarantine.

```
owl import /tmp/archive.tar.gz
```

### `owl logs [tail|show]`

Render structured logs.

```
owl logs
owl logs tail
owl logs tail --json
```

## `owl-daemon`

The background worker that watches inbound/outbound folders.

```
owl-daemon --env /home/pi/mail/.env
```

## POSIX shell usage tips

- Use `set -e` (or `set -euo pipefail` in shells that support it) for strict error handling.
- Check exit codes for commands without JSON output.
- Pipe JSON from `triage`/`logs` into `jq` or another JSON parser.

Example:

```
set -e
triage_json=$(owl --json triage --list quarantine)
printf '%s\n' "$triage_json" | jq '.[] | .address'
```
