# Privacy

Codex File Manager is a local desktop utility. It has no analytics, advertising, crash-reporting SDK, or application-operated server.

## Data the app reads

- Thread metadata returned by the user's local `codex app-server`, including titles, IDs, timestamps, working directories, and log paths.
- File and directory metadata needed to calculate disk usage and identify known build-cache directory names.
- Local Codex storage locations such as sessions, archived sessions, worktrees, caches, and application support data.

The app displays this information locally and does not upload it. It does not read or bundle ChatGPT/Codex account tokens. The separately installed Codex executable may communicate with OpenAI according to the user's Codex account and configuration.

## Changes the app can make

- High-confidence rebuildable caches are moved to the macOS Trash after user confirmation.
- Thread archive and permanent-delete requests are sent to the local App Server after user confirmation.
- Potential deliverables, credentials, private keys, certificates, `.env` files, and unknown directories are not automatic cleanup targets.

Permanent thread deletion is not recoverable from Trash. Users should commit or back up important work before deleting data.

## Network behavior

Codex File Manager starts App Server over local standard input/output (`stdio`) and does not open a listening network port. The app itself does not send telemetry. Codex may use the network as part of its normal operation.

## Reports

When filing an issue, remove conversation contents, full local paths, usernames, tokens, and other personal data from screenshots and logs.
