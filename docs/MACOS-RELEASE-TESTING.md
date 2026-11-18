# macOS release validation — v0.7.3 / build 19

Last updated: 2026-11-18. Distribution status: **Developer ID signed, Apple notarized and stapled; user reports successful operation on multiple machines. Offline clean-machine testing skipped by user decision**.

## Automated checks

| Check | Result |
| --- | --- |
| Portable regression and release-pipeline checks | PASS: 32 tests |
| Native CPU sampling, settings, controls and wallpaper fixtures | PASS |
| Native view and shared-world tests | PASS: all three modes, per-display crops, explicit overview, scaled host views and T-layout remote-coordinate cases |
| Modern adaptive simulation | PASS: synthetic 128-CPU E/P/S/unknown topology, grids and per-CPU scheduling |
| Address/undefined-behavior sanitizer stress | PASS: 36,300 desktop-domain passes; 160,000 historical 4.2 passes and 20,000 session intervals; 19,200 enhanced-coordinate/domain passes |
| Build and ad-hoc bundle signatures | PASS |
| Development DMG | PASS: HFS+ creation and checksum verification; earlier packaging rehearsal also verified a read-only mount and all 11 payload file hashes |

Run `./tools/run-macos-tests.sh` for current results. Release preparation retains its own `checks.log` and artifact checksum in `build/releases/`. These artifacts and logs are not committed.

## Signed release candidate — 2026-11-18

- Source: `277d0e7b5a3ca9112044f34f7a1f4039baf53a6b`, clean checkout at preparation.
- Artifact: `NetWareSnake-0.7.3-build19-arm64.dmg` (Apple Silicon, macOS 13+).
- Final SHA-256 after stapling: `c65439e97d37a5045c1ed0deb92e9c085ac8019461e5df320d5acc3a4433d32d`.
- Full automated suite repeated successfully during signed preparation.
- Both bundles signed with Developer ID Application, secure timestamps and hardened runtime; signature verification passed.
- Bundles submission `ea8ddd0f-268c-4cc7-b4a5-0cda1854a5e7`: Accepted, no issues. Preview ticket stapled and validated.
- DMG submission `6b2700c5-16c9-4b72-be20-ccf0e7be8f13`: Accepted, no issues. DMG ticket stapled and validated; signature verification passed.
- Local Gatekeeper DMG assessment: accepted, `source=Notarized Developer ID`.
- Apple logs hash the submitted DMG before stapling; the final checksum above covers the stapled distribution file.
- `.saver` is covered by Apple's acceptance and the stapled DMG; direct saver stapling is unsupported. Clean-account/offline saver activation remains untested and was explicitly skipped by the user.
- Bundled README/changelog describe the earlier development status; `RELEASE-STATUS.txt` identifies the signed candidate. This record documents the completed Apple stages without altering the accepted payload.
- Artifacts and service logs remain local under `build/releases/20261118T142714.579714Z/`. The v0.7.3 GitHub release uses this exact finalized artifact and checksum.

## User-reported field results

| Check | Result |
| --- | --- |
| New installation, upgrade and removal | PASS, reported 2026-11-17 during development packaging tests |
| Two displays, side by side | PASS, including snakes crossing the screen boundary |
| Three displays, side by side | PASS, initially reported with build 16 |
| Three displays, T arrangement | PASS with build 19 after reloading the cached host |
| Signed/notarized build on multiple machines | PASS, user reports no issues with installation/activation and expected behavior |

These are user-reported visual/functional results. Exact Mac model, macOS version, animation mode, fresh-account conditions and preference-retention details were not recorded for every test. They do not establish all-layout compatibility or notarized distribution acceptance.

### T-layout resolution

Builds 16–18 showed whole-scene duplication or lower-display mirroring. The actual build-18 host log showed missing upper screen IDs and negative-Y remote rectangles, which selected the lower screen as fallback. Build 19 added exact matching in both desktop coordinate systems.

The first post-update report contained build-19 fixture logs but only build-18 actual-host logs. After replacing the saver and restarting `legacyScreenSaver`, the user confirmed the T layout looked exactly as expected. For update investigations, verify the build tag from the actual host, not just the Options footer or fixture logs.

The captured host served all three displays in one process. Sharing remains process-local; separate host processes do not synchronize.

## Pending public-distribution checks

- Gatekeeper acceptance of a browser-downloaded, quarantined final release.
- Fresh-account/offline installation and launch without cached tickets: **SKIPPED**, explicitly accepted by the user for this release; no clean machine available.
- Rollback, sleep/wake and other display/host configurations beyond those reported above.

Use [the release procedure](MACOS-RELEASE.md) for the complete checklist. Record exact artifact SHA-256, version/build, Mac model, macOS version, layout, date and outcome for new field tests. Do not include account details or credentials.
