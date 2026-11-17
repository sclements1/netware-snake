# v0.7.0 — Modern adaptive mode

- Enabled Modern with Unified desktop defaults, detected host CPU count and up to 128 snakes.
- Added per-logical-CPU E/P/S topology detection and Small/Medium/Large size grids; unknown types use Medium.
- Retained independent Modern preferences and 4.2-derived movement with per-CPU measured loads.
- Added synthetic 128-CPU adaptive-grid and scheduling tests.

# v0.6.0 — Colors and expanded 4.2 configuration

- Added a 3.12 color picker, defaulting to Faithful red.
- Exposed all shared controls in 4.2, including Unified desktop, wallpaper consumption, crossing protection, speed and size.
- Added 32 ordered CPU color positions and continuous historical palette rotation.
- Added detected-31, detected-32 and Fixed 32 CPU policies. Fixed 32 forces phased simulated loads; leaving it restores the prior source.
- Saved independent mode profiles with read-only migration from previous settings.
- Preserved default historical engine behavior and added full-width enhanced histories.

# v0.5.0 — Settings, unified desktop, and wallpaper trail

- Replaced the old Faithful/Customizable/SMP menu with exactly **NetWare 3.12**, **NetWare 4.2**, and **Modern**. Modern remains disabled with an explanatory hint; no modern engine or behavior has been invented.
- Consolidated 3.12 settings into Resolve gaps; Screen mode (**4:3**, **Widescreen**, **Unified desktop**); Eat the desktop; Speed (**0.5×**, **1×**, **2×**); Size (**Small**, **Medium**, **Large**); and CPU source (**Measured**, **Stepped demo**). The snake stays red and the color selector is removed.
- Added a native draft-based settings sheet. Mode switches preserve unsaved edits. Restore Defaults resets the visible mode's draft without saving or confirmation; Save persists and Cancel discards. Read-only legacy migration distinguishes the old mode indices from the new schema and maps old speeds to the nearest supported choice.
- Added one process-local 3.12 world and clock for Unified desktop mode, with display-layout boundaries and passable adjoining seams. Ordinary 4:3/Widescreen worlds and the 4.2 per-display consoles remain independent. Separate screen-saver processes do not share a world.
- Reintroduced Eat the desktop using a frozen wallpaper file obtained through public NSWorkspace APIs. It captures no applications, windows, or desktop screen contents. Visited trail cells become black. Dynamic pictures use an available still frame; inaccessible or unsupported pictures use the desktop fill color or black. Public metadata cannot reproduce every wallpaper mode, including tiling.
- Added preview shortcuts: **Command-comma** for Settings, **Command-Shift-F** for all displays/window, and **Escape** to return to the window.
- Kept the recovered 4.2 engine, live per-CPU sampling, original crossing erasures, startup staggering, palette cycle, and existing 31/32 CPU-cap option. Its sheet shows only the CPU-cap option and host CPU count.
- Bumped saver, preview, installer checks, and loaded-bundle footer to **v0.5.0/build 14**. Added settings, wallpaper, visited-trail, and synthetic display-layout validation.

Validation boundary: physical multi-monitor operation inside the macOS system screen saver remains pending. Unified sharing is within one host process; the all-display preview provides a direct layout check. Historical font pixels, exact DAC colors, and kernel timing/scheduling jitter remain approximation boundaries. The v0.4 original-instruction evidence below continues to apply to the retained 4.2 engine.

# v0.4.0 — NetWare 4.2 Faithful

- Added the instruction-validated 4.2 engine as a third mode, preserving both 3.12 modes and their stored settings.
- Maps host logical CPUs to snakes, capped at 31 by default with an explicit option allowing 32.
- Uses live per-CPU Mach counter deltas, cached for half a second; first samples establish a baseline. Handles 32-bit wrap, failures and CPU count changes.
- Preserves the shared 55-word RNG, palette cycle, center origin, eight directions, boundary retries, 40-pass turns, load-dependent history lead, five-stage shade/erase writes and destructive crossings.
- Staggers CPU p by 4*p nominal 18.2-Hz intervals. Ascending CPU order resolves simultaneous updates. Activations clear the screen and reset palette allocation while retaining the module's random sequence.
- Settings show the selected CPU count and disable unrelated Customizable controls in 4.2 mode. Bumped saver, preview and installer to v0.4.0/build 13.
- Added scheduler, CPU-cap, startup palette, load-band, restart, native sampling and sanitizer tests. Adjusted an existing geometry test to tolerate sub-pixel floating-point roundoff at an exactly flush edge; the 3.12 engine and geometry code are unchanged.

Validation: 21 tests, native CPU-reader fixtures, 160,000 sanitized engine passes, 20,000 sanitized session intervals, native build/signatures, 38,080 original-instruction comparisons, 20,000 original RNG outputs and 320 original worker passes pass. Automated preview-launch inspection timed out; visual validation remains pending. Font-ROM pixels, exact DAC colors and kernel scheduling/timer jitter remain approximation boundaries.

# v0.3.0 — lean cleanup and Faithful VGA presentation

- Completely removed Eat the Desktop, wallpaper lookup and decoding, image orientation controls, erosion masks, wallpaper logging and performance diagnostics tied to wallpaper rendering.
- Fixed Faithful display geometry: exactly 80×25 text cells, 8×16 pixel glyph proportions, centered in a logical 640×480 (4:3) VGA viewport with a 640×400 text raster and 40 virtual blank scanlines above/below. Uniform scale across screen aspect ratios; no widescreen stretching.
- Preserved Customizable widescreen, color shading, cell size, speed, live CPU/demo, optional crossing protection and Restore Defaults.
- Added a version/build footer to the Options sheet, obtained from the actual loaded bundle's Info.plist.
- Kept diagnostics opt-in and quiet in normal use; retained the checked installation and backup scripts.
- No changes to the historically validated C snake state machine.

**Verification limit:** Portable regression tests pass. Native compilation and screenshots need validation on a Mac.
