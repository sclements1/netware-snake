# NetWare Snake for macOS v0.7.0

A native macOS screensaver and standalone preview with researched NetWare 3.12 and NetWare 4.2 simulations. This release is **build 16**.

## Modes and settings

The Mode menu contains exactly **NetWare 3.12**, **NetWare 4.2**, and **Modern**. Modern is enabled. It defaults to a Unified desktop, measured per-CPU loads, 1× speed, the CPU 0 palette start, original gaps and wallpaper off. This first Modern implementation uses a unified canvas; the screen selector is locked to Unified. CPUs is a read-only host logical processor count, with up to 128 snakes. Size is read-only Adaptive: E = Small, P = Medium, S = Large. Unrecognized or unavailable core metadata uses Medium. Core types are read from IODeviceTree cluster-type and logical-cpu-id rather than guessed from processor ordering. Intel and restricted hosts may lack this metadata. Each Modern snake runs a 4.2-derived simulation on its own size grid; the historical shared RNG and destructive inter-snake erasures are not reproduced between these differently sized layers. The first snake starts immediately, with subsequent snakes staggered four simulation intervals apart.

**NetWare 3.12** uses the original single red snake. Its options are:

| Option | Choices and behavior |
| --- | --- |
| Resolve gaps | Preserve the original crossing erasures when off; keep crossings filled when on. |
| Screen mode | **4:3 mode**, **Widescreen mode**, or **Unified desktop mode**. |
| Eat the desktop | Start with a frozen wallpaper image; trail cells become black as the snake visits them. |
| Animation speed | **0.5×**, **1×**, or **2×**. |
| Size | **Small**, **Medium**, or **Large**. |
| CPU load source | **Measured** aggregate host CPU utilization, or a **Stepped demo** through the load bands. |

Defaults are 4:3 mode, Medium, 1×, Measured CPU, original crossing gaps, and Eat the desktop off. The default 4:3/Medium presentation retains an 80×25 grid in a centered 640×480 logical VGA viewport. Its 640×400 text raster has 40 virtual blank scanlines above and below. Other sizes change the grid density; Widescreen expands the grid for the screen's aspect ratio. The color picker defaults to Faithful red (`#AA0000`).

**NetWare 4.2** exposes the same screen, gap, wallpaper, speed, size and CPU source controls. Its **CPU 0 color** menu lists CPU 0 through CPU 31 with swatches in historical order. Selecting a starting position advances subsequent snakes through the continuous 15-color cycle. Default CPU 0 preserves the historical sequence.

The **CPUs** menu offers detected CPUs capped at 31 (historically accurate), detected CPUs capped at 32, or **Fixed 32**. Fixed 32 always creates 32 snakes and forces **Simulated load**; leaving it restores the prior Measured/Stepped demo selection. Simulated loads vary by CPU through phased load bands.

The 4.2 snakes start from column 38, row 12 (zero based), two characters wide, staggered by four simulation intervals per CPU. The nominal rate is 18.2 passes/second, supported by the supplied startup recording. CPU 31 first draws about 6.8 seconds after CPU 0. Their trails change length and motion with each CPU's utilization; they are not recolored copies of the 3.12 snake. 4:3 and Widescreen keep independent consoles; Unified desktop shares all snakes across the display layout.

Settings edits stay in a draft while switching modes. **Restore Defaults** resets the visible mode's draft without confirmation or saving. **Save** applies it; **Cancel** discards it. Existing v0.4 Faithful preferences map to 3.12 defaults, Customizable preferences map to the corresponding 3.12 controls with the closest available speed, and SMP preferences map to 4.2 with the CPU-cap choice preserved. Each mode now retains its own profile, including color and load-source choices. Migration does not write preferences until Save.

## Unified desktop and wallpaper

In **Unified desktop mode**, participating display views share one selected-mode world and clock within their host process. The grid follows the macOS display arrangement: adjoining screens share a seam, while areas outside the actual displays are boundaries. A windowed preview fits the full layout into its window; the all-display preview shows each display's portion.

Sharing is **process-local**. Separate screen-saver host processes do not synchronize with one another. Physical multi-monitor behavior in the macOS system screen saver still needs validation; the all-display preview is provided to inspect the shared layout directly. The ordinary 4:3 and Widescreen modes keep independent per-display worlds.

Eat the desktop reads the configured wallpaper file and public scaling/fill options through **NSWorkspace** when an activation begins. It does **not** capture application windows, icons, or the on-screen desktop, and does not use screen recording. The picture stays static while visited trail cells turn black; restarting starts with a fresh picture and trail mask.

Wallpaper matching has limits. Dynamic pictures use one available image frame. Missing, inaccessible, or unsupported wallpaper files fall back to the desktop fill color, or black when no fill color is available. Public wallpaper metadata does not describe every macOS wallpaper mode, including tiling, so an exact match to the current desktop is not guaranteed. Snapshot rasters are bounded to 4096 pixels per axis.

## Research and fidelity

The 4.2 engine was recovered from the supplied unpacked **MON42U.NLM**, SHA-256 `0a1940dbf942abfb02db4c1690336b85454e7efd0656ea3a36cdace2f13f6c69`. Its portable implementation and modern host adapter are separate in `core/nw4_snake.c` and `core/nw4_session.c`. The integrated engine passed **38,080 differential passes** against original MONITOR instructions, **20,000 RNG outputs**, and **320 original worker passes**. Original proprietary binaries are not distributed.

Character codes DB/B2/B1/B0 and the erase space are verified against the supplied kernel and NWSNUT instructions. Rendering uses CP437-like density masks and conventional VGA RGB colors. Exact historical font-ROM pixels, DAC colors, and scheduler jitter are not claimed. The 3.12 geometry, wallpaper, crossing protection, and unified-desktop choices are modern adaptations around the recovered behavior. See [the 4.2 notes](docs/NETWARE42.md) for source hashes, original-instruction repeatability, and adaptation boundaries.

## Build, preview and install

Requires macOS 13+ and Apple Command Line Tools. Builds target the compiling Mac's architecture. Bundles are locally ad-hoc signed; they are not Developer ID signed or notarized.

```sh
./build-macos.sh
open build/NetWareSnakePreview.app
```

Preview shortcuts:

- **Command-comma** opens Settings.
- **Command-Shift-F** switches between the window and a preview across all displays.
- **Escape** returns from the all-display preview to the window.

Select a mode, adjust its visible controls, and Save. After checking the preview, quit System Settings and run:

```sh
./install-macos.sh
```

The installer checks **v0.7.0/build 16** before replacing the saver and backs up the prior one as `~/Library/Screen Savers/NetWareSnake.previous.saver`. Building alone does not install anything. The Settings footer obtains its version/build from the actual loaded bundle. Normal operation logs no animation frames or CPU samples.

## Validation

```sh
./tools/run-core-tests.sh       # portable regression tests, including 3.12 parity
./tools/run-macos-tests.sh      # native fixtures, sanitizers, bundles and signatures
```

The project includes native settings migration/persistence tests, actual AppKit control and draft-behavior checks, wallpaper fixtures, visited-trail tests, and synthetic multi-display geometry tests. These complement the historical engine comparisons; they do not replace physical multi-monitor system-saver validation.

For a visual check, open Settings and confirm **v0.7.0 · build 16**. Check the shared controls and color choices, switch to 4.2 and back before saving, and verify Restore Defaults followed by Cancel leaves saved settings unchanged. In Unified desktop mode, use Command-Shift-F to inspect display seams and Escape to return. With Eat the desktop enabled, verify the wallpaper remains static and the visited trail becomes black. Finally check 4.2's center startup, colors, per-CPU response, and 31/32 cap on a host with enough logical CPUs. If the system saver retains an old build, quit and reopen System Settings after installation.
