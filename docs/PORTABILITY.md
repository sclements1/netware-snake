# Portability and future-platform contract

## Core is plain C11

`nw_snake.h` and `nw_geometry.h` provide the 3.12 engine and shared geometry. `nw4_snake.h` and `nw4_session.h` add the 4.2 engine and CPU/staging policy. No `Foundation`, `CoreGraphics`, Mach, AppKit, ScreenSaver, Swift, threading, or UI framework types are referenced by the engine. A Windows (`.scr`), Linux (Wayland/X11), or future macOS screen-saver host can link these C11 sources directly.

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
- More than 32 snakes and custom CPU/core/cluster layouts.
- Metal, Direct3D, and advanced GPU pipelines.
- Original VGA font ROM extraction or exact console DAC color reproduction.
- Synchronization of snake *path* across separate physical displays (each display gets an independent console, sharing aggregate samples in 3.12 or per-CPU samples in 4.2).
- Official Apple Developer ID signing/notarization for redistribution.


## NetWare 4.2 adapter

Create an `nw4_session`, start it with the host logical processor count and allow32 flag, and tick it at nominal 18.2 Hz with an array of integer percentages in processor enumeration order. Render both 80×25 planes: character AND foreground attribute. A shared destructive console cannot be reconstructed by overlaying independently drawn snakes. Keep the session between activations; `nw4_session_start` clears the console and palette while retaining shared RNG state. Stop advancing while the saver is inactive. Each independent display owns a session.

The Mac sampler supplies 0..100 per logical CPU, cached for 0.5 seconds. Missing loads become zero and oversized adapter loads clamp to 100. The low-level verified engine instead rejects invalid percentages. Session ticks stagger first execution by 4*p intervals, then step each due CPU once in ascending index order. This is a documented modern ordering policy, not a reproduction of the NetWare kernel scheduler. Rendering/presentation may run at 30 Hz with an elapsed-time simulation accumulator. A 0.25-second elapsed-time cap prevents sleep/wake catch-up bursts.
