# Stellar AI Notes

- Stellar is in a first-phase Theurgy posture.
- `theurgy.project.toml` is the explicit contract boundary for the native desktop app.
- The current backend remains `scripts/stellar-backend.sh`; do not treat that as accidental drift.
- The right migration shape is narrow and staged: typed runtime contracts first, then isolated high-value backend slices, not a wholesale rewrite.

## Durable State

- Canonical mail data root defaults to `~/mail`.
- Stellar metadata lives under `ROOT/.stellar`.
- SimpleX runtime state lives under:
  - `ROOT/.stellar/simplex`
  - `ROOT/.system/simplex`
  - `ROOT/.transport/simplex`
- Desktop UI prefs currently live at `${XDG_CONFIG_HOME:-$HOME/.config}/wizardry-apps/stellar`.
- If that config path changes later, use migration-on-read or startup migration; do not strand existing data.

## Current Exception Boundaries

- POSIX shell remains the primary backend orchestration layer.
- Generated native hosts for macOS, Linux, Android, and iOS are intentional.
- Python may appear in supporting validation or generation surfaces outside the hot user path; keep those boundaries explicit if they grow.
- Do not add ad hoc repo-local runtime state, logs, caches, or temp homes.
- Generated host output belongs under `${XDG_STATE_HOME:-$HOME/.local/state}/stellar/generated` for desktop and `${XDG_STATE_HOME:-$HOME/.local/state}/stellar-mobile/generated/mobile` for mobile, not under repo-local `generated/` paths.

## Theurgy Guidance

- Prefer using Theurgy to own:
  - typed runtime manifests
  - native adapter compilation/staging
  - long-running transport and sync operation status
  - mobile/desktop runtime request envelopes
- Do not move mail storage, message history, or transport truth out of plain files unless a real scale or transactional need forces it.
- Treat `scripts/stellar-backend.sh` as the compatibility backend until a typed runtime bridge replaces specific actions.

## Migration Priority

1. Add Product IR, desktop/mobile surface IR, and runtime manifest contracts that describe the current app honestly.
2. Move status, snapshot, and settings-control actions behind a typed runtime request path.
3. Migrate long-running remote setup, sync, and transport operations with explicit operation-status/history contracts.
4. Only then consider deeper backend decomposition.
