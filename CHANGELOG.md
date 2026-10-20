# v0.3.0 — lean cleanup and Faithful VGA presentation

- Completely removed Eat the Desktop, wallpaper lookup and decoding, image orientation controls, erosion masks, wallpaper logging and performance diagnostics tied to wallpaper rendering.
- Fixed Faithful display geometry: exactly 80×25 text cells, 8×16 pixel glyph proportions, centered in a logical 640×480 (4:3) VGA viewport with a 640×400 text raster and 40 virtual blank scanlines above/below. Uniform scale across screen aspect ratios; no widescreen stretching.
- Preserved Customizable widescreen, color shading, cell size, speed, live CPU/demo, optional crossing protection and Restore Defaults.
- Added a version/build footer to the Options sheet, obtained from the actual loaded bundle's Info.plist.
- Kept diagnostics opt-in and quiet in normal use; retained the checked installation and backup scripts.
- No changes to the historically validated C snake state machine.

**Verification limit:** Portable regression tests pass. Native compilation and screenshots need validation on a Mac.
