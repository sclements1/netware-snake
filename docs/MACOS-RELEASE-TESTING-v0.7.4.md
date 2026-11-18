# macOS release validation — v0.7.4 / build 20

Last updated: 2026-11-18. Status: **Developer ID signed, notarized and stapled; installation/activation check passed (user-reported)**.

## Artifact and provenance

- Source: `c2a7795dca836d8a90b3e84c6f435de83319a2c6`, clean checkout during preparation.
- Target: Apple Silicon, macOS 13+.
- Artifact: `NetWareSnake-0.7.4-build20-arm64.dmg`.
- Final SHA-256 after stapling: `f1b18d12a24d2cd55a9ce1ae4723edc64853d84b3f6e700ce4562f7c8deb43da`.
- Local artifact/log directory: `build/releases/20261118T154810.426463Z/` (ignored).
- The previous v0.7.3 release and its assets are retained unchanged.

## Completed checks

| Check | Result |
| --- | --- |
| Portable regression and release checks | PASS: 33 tests |
| Native sampling, settings, controls, wallpaper and shared rendering fixtures | PASS |
| T-layout remote frames, per-display crops and overview rendering | PASS: all three modes |
| Modern adaptive simulation | PASS: synthetic 128-CPU topology and scheduling |
| Address/undefined-behavior sanitizer stress | PASS: 36,300 desktop-domain passes; 160,000 historical 4.2 passes and 20,000 session intervals; 19,200 enhanced-coordinate/domain passes |
| Gitleaks history and tracked-change scan | PASS: no secrets found |
| Developer ID bundle signing | PASS: team verified, secure timestamp and hardened runtime |
| Bundles notarization | Accepted: `c72b64b0-6d9c-47ec-8365-2c042379b7a1`, no issues |
| DMG notarization | Accepted: `c40a3957-2309-49d1-af54-e9a111536c46`, no issues |
| Ticket stapling/validation | PASS: preview app and final DMG |
| Local Gatekeeper | PASS: preview execution and DMG open assessment; Notarized Developer ID |
| Mounted DMG | PASS: read-only mount, expected payload, both bundles v0.7.4/build 20 and strict signature verification |
| Final checksum | PASS: finalized DMG hash verified |
| Public distribution | PASS: repository public; anonymous DMG and checksum downloads match the finalized hash; v0.7.4 is the latest release |

Apple's log hashes the submitted DMG before stapling. The final SHA-256 above
covers the stapled file. The saver is covered by Apple's acceptance and the
stapled DMG; `.saver` bundles do not support direct ticket stapling.

## Field results and limits

- Build 20 installation/activation: PASS, user confirmed the signed DMG installs and the saver activates correctly with the build 20 Options footer on 2026-11-18. Exact machine model and macOS version were not recorded.
- Prior v0.7.3 results: user reports successful installation/activation on multiple
  machines. Earlier development tests passed horizontal and T display layouts;
  see [the earlier record](MACOS-RELEASE-TESTING.md).
- Clean-machine/offline validation was explicitly skipped in the prior release
  process because no clean machine was available. It remains untested here.
- Browser-downloaded quarantine handling, broader host/display combinations,
  rollback and sleep/wake are not established by the local checks above.
- Unified sharing remains process-local. No cross-process synchronization claim.
