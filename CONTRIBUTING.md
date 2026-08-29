# Contributing

Thanks for helping improve Codex File Manager.

## Development

Requirements: macOS 14 or later, Xcode Command Line Tools, and a local Codex installation for integration testing.

```bash
swift test
swift run CodexFileManager
```

Before opening a pull request:

1. Keep cleanup behavior conservative. New automatic-cleanup rules must identify data that is reliably rebuildable across supported tool versions.
2. Add or update tests for path validation, deduplication, and cleanup classification.
3. Run `swift test` and `./scripts/build-app.sh`.
4. Do not commit `.build`, `dist`, local conversation logs, screenshots containing private paths, tokens, or signing credentials.
5. Update the README and changelog when user-visible behavior changes.

Compatibility reports should include the Codex version and a redacted App Server error. Never attach raw conversation files.
