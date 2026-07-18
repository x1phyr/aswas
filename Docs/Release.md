# Release and Notarization

## Local app bundle

```sh
./Scripts/build-app.sh
```

The default build is ad-hoc signed with Hardened Runtime for local testing. Output:

```text
build/Release/aswas.app
```

## Developer ID build

Set the exact Developer ID Application identity in the environment:

```sh
ASWAS_SIGNING_IDENTITY="Developer ID Application: Example (TEAMID)" \
  ./Scripts/build-app.sh
```

Verify before submission:

```sh
codesign --verify --deep --strict --verbose=2 build/Release/aswas.app
codesign --display --verbose=4 build/Release/aswas.app
spctl --assess --type execute --verbose=4 build/Release/aswas.app
```

## Notarization

Create a zip that preserves the bundle, submit it, and staple the accepted ticket:

```sh
ditto -c -k --keepParent build/Release/aswas.app build/Release/aswas.zip
xcrun notarytool submit build/Release/aswas.zip --keychain-profile ASWAS_NOTARY --wait
xcrun stapler staple build/Release/aswas.app
xcrun stapler validate build/Release/aswas.app
```

The `ASWAS_NOTARY` keychain profile must be created locally with Apple's `notarytool`
credentials. Credentials are never stored in this repository.

## Release checklist

- Run `swift test`.
- Run the Finder manual test plan on macOS 14 and the current macOS release.
- Verify first-run Automation consent from the signed app bundle.
- Verify permission denial, later grant, and revocation.
- Verify Open and confirmed Replace modes.
- Verify Save & Close never closes after a forced persistence failure.
- Verify display removal and at least one real multi-display arrangement.
- Confirm Finder tabs are described as best effort, not full fidelity.
- Confirm logs do not expose private paths in the release build.
- Notarize, staple, and assess the exact artifact to distribute.
