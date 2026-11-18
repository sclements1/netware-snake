NetWare Snake v0.7.3 (build 19) is now available as a Developer ID signed, Apple notarized and stapled DMG.

## Download and install

Requires **Apple Silicon and macOS 13 or later**. Download `NetWareSnake-0.7.3-build19-arm64.dmg` below. Open it and follow `START-HERE.txt`: try the preview app, or double-click the saver to install it. Quit System Settings before upgrading. If an older saver remains loaded, restart the Mac.

The matching `.sha256` file verifies the DMG download. The bundled README/changelog retain the development status from preparation; notarization was completed afterward. The release artifact is signed and notarized.

## Changes

- Fixed mirrored displays and incorrect per-display crops in Unified Desktop T layouts.
- Preserved character proportions for scaled screen saver host views and separated full-desktop preview overviews from physical-display rendering.
- Added changed-mapping diagnostics and regression coverage across NetWare 3.12, NetWare 4.2 and Modern modes.
- Added signed distribution packaging, notarization, installation/upgrade/removal instructions and checksums.

## Validation and known limits

All 32 portable tests, native fixtures, synthetic 128-CPU Modern tests, sanitizer stress and signature checks passed. Apple accepted both bundles and the final DMG without issues; tickets validate and local Gatekeeper assessment passes. User testing passed on multiple machines, including horizontal and T display layouts during development.

Clean-machine offline installation was **skipped by user decision**. Unified Desktop sharing remains within one host process; separate screen saver processes do not synchronize. Additional display/host configurations and sleep/wake behavior remain unverified.

Source used to build the binaries: `277d0e7b5a3ca9112044f34f7a1f4039baf53a6b`.

Final stapled DMG SHA-256:

```text
c65439e97d37a5045c1ed0deb92e9c085ac8019461e5df320d5acc3a4433d32d
```
