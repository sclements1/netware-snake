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
