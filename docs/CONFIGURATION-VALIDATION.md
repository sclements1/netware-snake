# Configuration and rendering validation

Current validation is consolidated in [the macOS release record](MACOS-RELEASE-TESTING.md).

The native fixtures cover independent 3.12/4.2/Modern drafts, read-only settings migration, Restore/Cancel/Save, colors and CPU policies, forced simulated loads, wallpaper snapshots and persistent trails. Rendering fixtures cover the historical Medium 4:3 origin, adaptive Modern grids, display crop isolation and explicit overview rendering.

The recovered default 3.12 and 4.2 behavior remains covered by portable regression tests. Enhanced geometry, crossing protection, wallpaper consumption and Modern per-snake grids are adaptations, as described in [the README](../README.md) and [4.2 research notes](NETWARE42.md).

Run `./tools/run-macos-tests.sh` to repeat the automated checks. User-reported physical results and pending signing/notarization tests are recorded separately in the release record rather than inferred from fixtures.
