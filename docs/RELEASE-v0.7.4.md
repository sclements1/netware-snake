NetWare Snake v0.7.4 (build 20) is Developer ID signed, Apple notarized and stapled. It reduces routine diagnostic logging and improves documentation and release safeguards.

## Download and install

Requires **Apple Silicon and macOS 13 or later**. Download `NetWareSnake-0.7.4-build20-arm64.dmg` from Assets, open it and follow `START-HERE.txt`. Try the preview app, or double-click the saver to install it. Quit System Settings before upgrading. Confirm the Options footer shows **v0.7.4 · build 20**; restart the Mac if an older saver remains cached.

The DMG contains the saver, preview, installation guide, license, changelog and provenance notes. The matching `.sha256` file verifies the download. v0.7.3 remains available for rollback.

## Changes

- Detailed display mapping diagnostics are now opt-in and omit raw object addresses. Normal operation no longer emits display mapping details.
- Updated documentation for all three modes, Unified Desktop and signed distribution; added contributor, security reporting and provenance guidance.
- Added portable-test and history secret-scanning CI, plus ignore rules for local signing material, environment files, diagnostics and proprietary research inputs.
- Signed release preparation rejects dirty checkouts. Distribution documentation now includes a self-contained installation guide and provenance notes.
- Reformatted host adapters and research/release tooling. Recovered snake algorithms are unchanged.

## Research and fidelity

**NetWare 3.12** was reconstructed from static disassembly of MONITOR.NLM v1.76 (1993), first as a Python model and then as the portable C engine. Controlled-load VM recordings corroborated the five load bands, crossing gaps and nominal playback cadence. The C engine matches the reconstructed reference over **41,600 passes across 64 seeds**, comparing the raw framebuffer and internal state. This is reference-model parity, not execution of original 3.12 instructions. [Recovery notes](https://github.com/sclements1/netware-snake/blob/main/docs/NETWARE312.md).

**NetWare 4.2** was recovered from unpacked MON42U.NLM. Validation includes **38,080 differential passes** against original instructions, **20,000 RNG outputs** and **320 original worker passes**, with glyph lookup checked through SERVER/NWSNUT instructions. [Recovery notes and source hashes](https://github.com/sclements1/netware-snake/blob/main/docs/NETWARE42.md).

Original proprietary binaries are not distributed. Exact font-ROM pixels, DAC colors and kernel scheduler timing are not claimed. Configurable geometry, wallpaper trails, crossing protection and Unified Desktop are modern adaptations.

## Validation and known limits

All 33 portable tests, native settings/rendering fixtures, synthetic 128-CPU Modern tests, sanitizer stress and signature checks passed. History secret scanning also passed. Apple accepted the bundles and final DMG without issues; preview and DMG tickets validate, and local Gatekeeper assessments accept both the preview and DMG. The signed build 20 installation and screen saver activation passed the user check, including the Options version/build footer.

Unified Desktop sharing remains within one host process; separate screen saver processes do not synchronize. Clean-machine offline testing was previously skipped by user decision and is not claimed as passed. Broader display configurations and sleep/wake behavior remain outside the verified field coverage.

Source used to build the binaries: `c2a7795dca836d8a90b3e84c6f435de83319a2c6`.

Final stapled DMG SHA-256:

```text
f1b18d12a24d2cd55a9ce1ae4723edc64853d84b3f6e700ce4562f7c8deb43da
```
