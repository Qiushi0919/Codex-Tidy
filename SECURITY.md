# Security Policy

## Supported versions

Security fixes currently target the latest published beta.

## Reporting a vulnerability

Please use GitHub's private **Report a vulnerability** form in the repository's Security tab. Do not open a public Issue for vulnerabilities that could delete unintended files, expose conversation data, or bypass cleanup protections.

Include the app version, macOS version, Codex version, and minimal reproduction steps. Remove tokens, conversation contents, usernames, and unrelated local paths before submitting.

## Safety invariants

- Automatic cleanup must remain limited to explicitly allowlisted, rebuildable directory names.
- Cleanup targets must resolve below the workspace selected by the user and must not be symbolic links.
- Potential deliverables and credential-bearing files must remain review-only.
- Permanent conversation deletion must require explicit confirmation and use the supported App Server method.
