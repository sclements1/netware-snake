# NetWare Snake for macOS v0.3.0 — lean historical screensaver

A native macOS `.saver` and standalone preview, using the validated, portable NetWare 3.12 MONITOR.NLM snake simulation.

## What's in this build

- **NetWare 3.12 Faithful:** fixed 80×25 characters, original simulation (~18.2 passes/second), red shaded trail, live aggregate CPU, historical crossing gaps. The display is presented within a uniformly scaled, centered **640×480 logical VGA viewport (4:3)**. The text raster occupies 640×400 virtual pixels (80 × 8 by 25 × 16), leaving 40 virtual black scanlines at the top and bottom of the viewport. On widescreen monitors there are additional black side margins. It never adopts Customizable mode's widescreen, size, speed, color or overlap settings.
- **NetWare 3.12 Customizable:** same historical snake simulation, expanded text-grid widescreen support, selectable color with four CP437-like shading densities, three cell sizes, 0.5×–2× simulation speed, optional overlap protection, live CPU or a five-band demo sweep.
- **Multiple displays:** independent snake instances per screen with shared aggregate CPU sampling.
- **Diagnostics:** opt-in Apple unified logging; normal operation does not log animation frames or CPU samples.
- **Options footer:** reads *version and build* from the bundle running the saver, not from ScreenSaverEngine.

**Deliberately removed:** Eat the Desktop, wallpaper acquisition, bitmap decoding, erosion masks, related preferences and dependencies. Existing preferences from previous builds are ignored; upgrading doesn't modify wallpaper or delete user files.

## Build, preview and install

Requirements: macOS 13+, Apple Command Line Tools. These are source builds; they are not notarized for general distribution.

```bash
./build-macos.sh
open build/NetWareSnakePreview.app
```

After checking the preview, fully quit System Settings, then:

```bash
./install-macos.sh
```

The installer checks the build and version before replacing your current screensaver, and saves the previous one as `~/Library/Screen Savers/NetWareSnake.previous.saver`.

If Options does nothing immediately after installation, quit and restart System Settings. On some macOS 26 releases, the screensaver host also retains prior instances; close Settings before installing.

## What to verify on your Mac

1. Faithful on 16:9 or ultrawide: red snake occupies a **centered 4:3 virtual picture**; no full-width expansion. The text grid is 80×25, the outer viewport is 640×480 logical units.
2. Faithful remains fixed even after choosing Small, Widescreen and 2× in Customizable, then switching back.
3. Customizable widescreen still expands the playfield; colors retain shading and Restore Defaults works.
4. Options footer identifies `v0.3.0 · build 12`.
5. Try multiple screens and the native screensaver thumbnail as well as the standalone preview.
6. Compare CPU use with the high-cost wallpaper feature now absent.

## Tests

```bash
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

The original historical C simulation in `core/nw_snake.c` is unchanged. The Mac build must still be verified on a Mac with Apple's SDK; the container only exercises portable C and static source tests.
