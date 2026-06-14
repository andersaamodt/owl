# Stellar AI Notes

## Upstream Standards
- Read the repository README first.
- Read `/Users/andersaamodt/git/phronesis/standards/` for cross-repo policy.
- Read theurgy docs where Stellar depends on that generation and runtime-contract layer.

## Local Exception Ledger

### Language Boundaries
- POSIX sh: primary backend orchestration and transport control in `scripts/stellar-backend.sh`.
- Python: current backend helper snippets remain present and are removal-default unless explicitly re-approved during fix-it.
- Rust: none.
- C: generated native Linux output only.
- C++: none.
- Native/generated: generated native hosts for macOS, Linux, Android, and iOS are intentional.
- Other: Swift is intrinsic to macOS and iOS targets; mobile or desktop generated surfaces remain explicit native boundaries.

### Storage Roots
- Primary durable app data: `~/mail`
- Config: transport and metadata under `ROOT/.stellar`, `ROOT/.system/simplex`, and `ROOT/.transport/simplex`
- Cache: app-owned or transport-owned mail-root state only
- Logs: app-owned mail-root state only
- Temp/scratch: `${XDG_STATE_HOME:-$HOME/.local/state}/stellar/generated` and `${XDG_STATE_HOME:-$HOME/.local/state}/stellar-mobile/generated/mobile`

### Durable File Formats
- User-facing editable files: plain-text file-first corpus and settings files
- App-facing machine state: plain text and structured transport files
- Append-only logs: plain text where present
- Opaque formats and justification: mobile and desktop native artifacts are derived outputs only

### Theme System
- Classification: app-local native styling
- Catalog source: native app contract
- Ordering: local contract
- Keyboard contract: native controls own their keyboard behavior
- Persistence: current desktop UI prefs still live at `${XDG_CONFIG_HOME:-$HOME/.config}/wizardry-apps/stellar`, which remains an explicit storage exception
- Depth contract: keep native shells visually coherent without claiming shared wizardry-theme usage unless that becomes explicit

### Runtime And Bridge Ownership
- Backend action surface: `scripts/stellar-backend.sh` plus typed runtime contract scripts
- Backend path resolution owner: theurgy or native-host and backend contracts
- Shell-fragment policy: explicit backend actions only
- Native/generated boundary: generated native desktop and mobile shells around a shell backend and typed runtime contracts

### Tests
- Test entrypoints under `.tests/`: yes
- Backend contract coverage: yes
- UI/static/native-shell coverage: yes
- Known gaps: current Python helper snippets should be removed or replaced; the desktop UI prefs path remains a documented storage exception

### Release, Build, Generated Output, And Cruft
- Release artifact root: operator-local release outputs only
- Build output root: `${XDG_STATE_HOME:-$HOME/.local/state}/stellar/generated` and `${XDG_STATE_HOME:-$HOME/.local/state}/stellar-mobile/generated/mobile`
- Generated source roots: operator-local native output only
- Disposable cruft roots: no runtime state, logs, caches, or temp homes belong in the repo
- Repo-local generated fixtures: test fixtures and typed contract artifacts only

### Approved Exceptions
- Generated macOS, Linux, Android, and iOS native hosts are intentional.
- `~/mail` as the canonical durable root is intentional.

### Pending Decisions
- Remove the retained Python backend helper snippets unless a narrow subset is explicitly re-approved.
- Decide whether desktop UI prefs stay in the XDG config root or migrate fully into the `~/mail`-owned Stellar contract.
- Continue moving status, snapshot, settings-control, and long-running transport operations behind typed runtime request paths.
