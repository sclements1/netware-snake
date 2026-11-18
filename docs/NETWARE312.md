# NetWare 3.12: recovery and validation

The single-snake engine was reconstructed from static disassembly of
MONITOR.NLM v1.76 (1993). The recovered Python model is retained in
[`tests/python_reference.py`](../tests/python_reference.py); the portable C
implementation is [`core/nw_snake.c`](../core/nw_snake.c).
Original proprietary images are not distributed.

## From disassembly to a state machine

The reference records code/data-relative offsets rather than on-disk file offsets.
Recovery traced initialization, drawing, movement and history updates:

- An 80×25 character console, initial position (38,12), heading 2 and two adjacent
  character writes per snake position.
- A 51-slot circular coordinate/direction history with five paint/erase cursors,
  initially at slots 40, 30, 20, 10 and 0.
- Glyph bytes DB/B2/B1/B0/20 and paint order 4, 3, 2, 1, 0. The reference records
  the glyph table at relative offset `0x1c60` and drawing loop at code offsets
  `0x16f9–0x194a`.
- Eight direction vectors, boundary and reversal retries, and automatic direction
  selection every 40 passes. Seed updates use `((seed + 1) * 10013) mod 2^32`;
  deterministic tests substitute known seeds for the original DOSDateAndTime seed.
- CPU-dependent future-history writes using
  `((1280 / (floor(9*CPU/100) + 1) + phase) >> 7) mod 51`, with integer division.
  Head movement depends on a valid history slot; it is not an unconditional
  movement on every paint pass.
- Direct shade/erase writes without overlap protection. Older writes can overwrite
  newer segments, producing the original crossing gaps. Resolve gaps is a separate
  presentation enhancement, not a correction to the recovered state machine.

## VM recording cross-check

Archived Snake Lab v1.0 and five-band VM research compared the model with a
NetWare 3.12 QEMU/KVM recording under SNAKLOAD v0.5's controlled load sweep.
Stable-load observations supported five quantized movement cadences and nominal
18.2 simulation passes per second:

| CPU band | Model passes per head move | Head moves/s at 18.2 passes/s |
| --- | ---: | ---: |
| 0–11% | 10 | 1.82 |
| 12–22% | 5 | 3.64 |
| 23–33% | 3 | 6.07 |
| 34–55% | 2 | 9.10 |
| 56–100% | 1 | 18.20 |

The recordings measure visible framebuffer changes, not internal head moves or
kernel timer calls. In particular, the 28% experiment showed about 18.14 distinct
frames/s even though the model advances the head only about 6.07 times/s: shading
and erasure still change the framebuffer between head moves. Capture timing,
quantized utilization readings and an uncertain load-schedule offset limit the
precision of this cross-check. Unknown original seeds also prevent exact route
matching. The archived observations corroborate behavior and playback cadence;
they do not prove a pixel-exact emulator or NetWare scheduler equivalence.

## Current repeatability and limits

[`test_full_parity_across_64_seeds_and_41600_steps`](../tests/test_portable_core.py)
compares the C engine with the reconstructed Python reference at every pass:
2,000 character cells, position, heading, phase, random state, move count, all five
cursors and all 51 coordinate/direction history slots. Inputs cross load-band
boundaries and change over time. Run `./tools/run-core-tests.sh` from the checkout.

This establishes C-to-reference parity across **41,600 passes and 64 seeds**.
Unlike the 4.2 suite, this checkout has no original-instruction runner for 3.12;
the parity test does not independently execute MONITOR's original x86 code.
Exact historical font pixels, attributes, DAC colors and kernel scheduling remain
outside that claim. Configurable grids, wallpaper trails and Unified Desktop are
modern adaptations around the recovered engine.
