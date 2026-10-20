# Portability and future-platform contract

## Core is plain C11

`nw_snake.h` and `nw_geometry.h` are the only headers a future platform adapter needs. No `Foundation`, `CoreGraphics`, Mach, AppKit, ScreenSaver, Swift, threading, or UI framework types are referenced by the engine. A Windows (`.scr`), Linux (Wayland/X11), or future macOS screen-saver host can link these two libraries directly.

State ownership and main per-frame call:

```c
nw_snake *s = nw_snake_create(80, 25, random_seed);
unsigned changed = nw_snake_advance(s, cpu_utilization_0_to_100);
const uint8_t *cells = nw_snake_frame(s, /* overlap_protection */ 0);
// cells holds nw_snake_columns(s) * nw_snake_rows(s) CP437 byte values
nw_snake_destroy(s);
```

The host should translate monotonic elapsed time into **18.2** simulation passes/sec in Faithful mode, and sample aggregate CPU at an efficient rate. Rendering should use discrete density masks, preserving five stages and the spacing of the raw characters. For custom wide mode, use `nw_grid_for_view` and `nw_grid_metrics` rather than altering positions after they are simulated. Faithful presentation uses `nw_grid_metrics_for_mode(..., faithful=1, ...)` for a centered 640×480 logical VGA frame (with a 640×400 text raster); on any monitor it preserves 80×25 and 4:3 viewport proportions.

## Original behavior preserved

The expanded-grid world uses the *same* 51-slot history, five cursors, CPU divisor, direction table and 40-pass random turn mechanism, but alters only the geometric boundaries. As a result, a customizable widescreen world is mathematically an adaptation; it does **not** claim to be a version of MONITOR Novell ever released. In Faithful mode the test suite confirms complete state parity against the reference.

ScreenSaverView is the **macOS host adapter**, not the algorithm. Other platforms can choose different settings storage and CPU instrumentation. The user-selected color only affects output pixels, never the bytes in the faithful framebuffer.

## OS-specific risks

The Apple ScreenSaver framework officially supports subclassing `ScreenSaverView` with `animateOneFrame` and `configureSheet`, and `ScreenSaverDefaults` for preferences. Known macOS 26 Tahoe third-party host issues include duplicate/stranded instances and a secondary-monitor display bug (reported as FB19201567, FB19204084, FB19206021 in Apple Developer Forums). Those are not intrinsic to the game logic, and no native host implementation can guarantee Apple's multi-monitor host behaves correctly on every OS build.

- https://developer.apple.com/documentation/screensaver/screensaverview
- https://developer.apple.com/documentation/screensaver/screensaverdefaults
- https://developer.apple.com/forums/thread/787444

The lightweight core means even unwanted active instances should be comparatively inexpensive, but visual state management and a host bug may still consume resources. macOS host testing is necessary.

## Explicitly postponed

- Linux and Windows adapters.
- CPU-core/cluster-specific multiple-snake layouts and scale to hundreds of cores.
- Metal, Direct3D, and advanced GPU pipelines.
- Original VGA font ROM extraction or exact console DAC color reproduction.
- Synchronization of snake *path* across separate physical displays (presently each display gets an independent path, using the same aggregate CPU feed).
- Official Apple Developer ID signing/notarization for redistribution.

