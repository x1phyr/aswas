# Contributing to aswas

Thanks for helping make Finder context switching safer and more useful.

## Before you start

- Search existing issues before proposing a change.
- Keep pull requests focused on one behavior or concern.
- For behavior that mutates Finder windows, describe the safety boundary and failure behavior in the issue or pull request.
- Do not add private paths, usernames, account identifiers, tokens, or real workspace data to tests, fixtures, logs, screenshots, or documentation.

## Development setup

You need macOS 14 or later and Xcode 16 or later.

```sh
git clone https://github.com/x1phyr/aswas.git
cd aswas
swift build
swift test
```

Run the menu bar app from SwiftPM:

```sh
swift run aswas
```

Or create an ad-hoc signed app bundle:

```sh
./Scripts/build-app.sh
open build/Release/aswas.app
```

## Pull requests

1. Create a descriptive branch from `main`.
2. Add or update tests for behavioral changes.
3. Run `swift test` and, for packaging changes, `./Scripts/build-app.sh`.
4. Update both `README.md` and `README.zh-CN.md` when changing user-facing product information.
5. Add English and Simplified Chinese strings for every new user-facing label or message.
6. Fill out the pull request checklist and call out Finder window mutations explicitly.

## Finder integration rules

- Keep capture and restore code behind protocols so the domain and application layers remain testable.
- Never introduce a blanket close-all command.
- Save & Close must persist successfully before closing any captured window.
- Replace restore must remain previewed and confirmed.
- Treat Finder tabs as unsupported unless Apple exposes a stable public API and the capability PoC proves otherwise.
- Prefer structured errors and privacy-aware logging over raw system error text.

## Style

- Follow the existing Swift naming and formatting conventions.
- Prefer small types with explicit responsibilities.
- Keep UI-facing text in localization resources rather than inline string literals.
- Explain non-obvious safety decisions in code comments; avoid comments that merely restate the code.

By contributing, you agree that your contribution will be licensed under the MIT License.
