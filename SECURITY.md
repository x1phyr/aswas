# Security policy

## Supported versions

Security fixes are applied to the latest version on the `main` branch while the project is pre-1.0.

## Reporting a vulnerability

Please do not open a public issue containing exploit details, private paths, captured workspace data, or credentials.

Use GitHub's **Report a vulnerability** flow on the repository's Security tab when it is available. If private vulnerability reporting is not available, open a minimal issue requesting a private reporting channel without including sensitive details.

Include the affected commit or version, macOS version, expected security boundary, reproduction outline, and impact. You may redact all personal filesystem paths and account identifiers.

## Security boundaries

aswas stores workspace metadata locally and asks macOS for Finder Automation permission. It does not require Accessibility permission for the window-level workflow, and it does not provide cloud sync, analytics, or an account system.

Reports involving save-before-close ordering, unintended Finder window closure, path disclosure, damaged-workspace handling, signing, or update integrity are especially useful.
