# Configuration rebuild validation — v0.6.0 / build 15

Validated on the development Mac on 2026-10-27.

- `tools/run-macos-tests.sh`: PASS. The log is written to `build/tests/automated-checks.log` for this build.
- 27 portable tests: historical 3.12 parity across 41,600 steps, 4.2 behavior, aspect-preserving geometry, display seams, negative/staggered layouts, domain restrictions, and persistent consumed cells.
- Native fixtures: settings migration and persistence; configuration mode/control counts, disabled Modern, draft switching, Restore, Cancel, Save and notifications; wallpaper scaling, orientation, frozen source, fallback and raster limit; view restart/center, persistent erased wallpaper, Resolve gaps preserving the consumed mask, and shared-world lifetime.
- Address/undefined-behavior sanitizers: 36,300 desktop-domain passes; 160,000 4.2 passes and 20,000 session intervals.
- Both native bundles build and pass strict code-signature verification.
- Native GUI inspection: all requested 3.12 controls visible; Mode contains 3.12, 4.2 and disabled Modern; 4.2 retains only its CPU-cap control; Unified desktop preview shows the combined wallpaper layout; all-display preview opens and Escape returns to the window.

The 4.2 core now supports enhanced grids, copied display domains, full-width histories, persistent visited cells and protected crossing projections. Default behavior passes the existing regression checks. Native tests verify color rendering, Fixed 32 avoiding measured loads, measured-source restoration, both-mode wallpaper consumption and shared-world clocks.

## Remaining field check

Install the saver and check Unified desktop across the desired physical display arrangement in the macOS screen saver host. The shared world currently lives inside one process; separate host processes are not synchronized. The standalone preview deliberately creates every display view in one process for seam inspection.

Also compare Eat the desktop with the actual wallpaper choices in use. It freezes configured wallpaper image files, with a fill-color fallback if the file is unavailable; dynamic wallpaper and metadata unavailable through NSWorkspace may differ from the displayed desktop.
