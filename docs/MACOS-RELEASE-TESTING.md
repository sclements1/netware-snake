# macOS release validation — v0.7.3 / build 19

Last updated: 2026-11-17. Distribution status: **development/ad-hoc signed; not Developer ID signed or notarized**.

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

## User-reported field results

| Check | Result |
| --- | --- |
| New installation, upgrade and removal | PASS, reported 2026-11-17 during development packaging tests |
| Two displays, side by side | PASS, including snakes crossing the screen boundary |
| Three displays, side by side | PASS, initially reported with build 16 |
| Three displays, T arrangement | PASS with build 19 after reloading the cached host |

These are user-reported visual/functional results. Exact Mac model, macOS version, animation mode, fresh-account conditions and preference-retention details were not recorded for every test. They do not establish all-layout compatibility or notarized distribution acceptance.

### T-layout resolution

Builds 16–18 showed whole-scene duplication or lower-display mirroring. The actual build-18 host log showed missing upper screen IDs and negative-Y remote rectangles, which selected the lower screen as fallback. Build 19 added exact matching in both desktop coordinate systems.

The first post-update report contained build-19 fixture logs but only build-18 actual-host logs. After replacing the saver and restarting `legacyScreenSaver`, the user confirmed the T layout looked exactly as expected. For update investigations, verify the build tag from the actual host, not just the Options footer or fixture logs.

The captured host served all three displays in one process. Sharing remains process-local; separate host processes do not synchronize.

## Pending public-distribution checks

- Valid Developer ID Application identity and secure-timestamp signatures.
- Apple acceptance/log review for both bundles and final DMG; preview and DMG tickets stapled and validated.
- Gatekeeper acceptance of a browser-downloaded, quarantined final release.
- Fresh-account/offline installation and launch of preview and saver without cached tickets.
- Rollback, sleep/wake and other display/host configurations beyond those reported above.

Use [the release procedure](MACOS-RELEASE.md) for the complete checklist. Record exact artifact SHA-256, version/build, Mac model, macOS version, layout, date and outcome for new field tests. Do not include account details or credentials.
