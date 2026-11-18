NetWare Snake v0.7.3 (build 19) is now available as a Developer ID signed, Apple notarized and stapled DMG.

## Download and install

Requires **Apple Silicon and macOS 13 or later**. Download `NetWareSnake-0.7.3-build19-arm64.dmg` below. Open it and follow `START-HERE.txt`: try the preview app, or double-click the saver to install it. Quit System Settings before upgrading. If an older saver remains loaded, restart the Mac.

The matching `.sha256` file verifies the DMG download. The bundled README/changelog retain the development status from preparation; notarization was completed afterward. The release artifact is signed and notarized.

## Changes

- Fixed mirrored displays and incorrect per-display crops in Unified Desktop T layouts.
- Preserved character proportions for scaled screen saver host views and separated full-desktop preview overviews from physical-display rendering.
- Added changed-mapping diagnostics and regression coverage across NetWare 3.12, NetWare 4.2 and Modern modes.
- Added signed distribution packaging, notarization, installation/upgrade/removal instructions and checksums.

## Research and fidelity

**NetWare 3.12:** Reconstructed from static disassembly of MONITOR.NLM v1.76 (1993), first as a Python reference and then as the portable C engine. Recovery traced the 51-slot history, five paint/erase cursors, glyph/direction tables, random-state updates, boundary retries, 40-pass turns and CPU-dependent history writes. Controlled-load VM recordings corroborated five load bands, crossing gaps and nominal 18.2-pass/second playback. The C engine matches the reconstructed reference over **41,600 passes across 64 seeds and changing loads**, checking the raw framebuffer and internal state at every pass. This is reference-model parity, not direct execution of original 3.12 instructions. [3.12 research notes](https://github.com/sclements1/netware-snake/blob/main/docs/NETWARE312.md).

**NetWare 4.2:** Recovered from unpacked MON42U.NLM, SHA-256 `0a1940dbf942abfb02db4c1690336b85454e7efd0656ea3a36cdace2f13f6c69`. The integrated engine passed **38,080 differential passes** against original MONITOR instructions, **20,000 RNG outputs** and **320 original worker passes**. Glyph lookup was verified through the supplied SERVER and NWSNUT instructions. [4.2 research notes](https://github.com/sclements1/netware-snake/blob/main/docs/NETWARE42.md).

Original proprietary binaries are not distributed. CP437-like rendering, conventional VGA colors and nominal playback do not claim exact font-ROM pixels, DAC colors or kernel scheduler timing. Configurable geometry, wallpaper trails, crossing protection and Unified Desktop are modern adaptations.

## Validation and known limits

All 32 portable tests, native fixtures, synthetic 128-CPU Modern tests, sanitizer stress and signature checks passed. Apple accepted both bundles and the final DMG without issues; tickets validate and local Gatekeeper assessment passes. User testing passed on multiple machines, including horizontal and T display layouts during development.

Clean-machine offline installation was **skipped by user decision**. Unified Desktop sharing remains within one host process; separate screen saver processes do not synchronize. Additional display/host configurations and sleep/wake behavior remain unverified.

Source used to build the binaries: `277d0e7b5a3ca9112044f34f7a1f4039baf53a6b`.

Final stapled DMG SHA-256:

```text
c65439e97d37a5045c1ed0deb92e9c085ac8019461e5df320d5acc3a4433d32d
```
