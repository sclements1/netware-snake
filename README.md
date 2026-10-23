# NetWare Snake for macOS v0.4.0

A native macOS screensaver and standalone preview with separate NetWare 3.12 and NetWare 4.2 simulations.

## Modes

- **NetWare 4.2 Faithful:** one snake for each host logical CPU, capped at **31 by default**. Select **Allow up to 32 CPUs** to raise that cap to 32. A 16-CPU Mac gets 16 snakes with either setting; the option does not invent extra CPUs. Uses live utilization from each corresponding CPU, the recovered center origin, 15-color assignment cycle, shared random sequence, direction/boundary rules, five-stage trail, load-dependent history and original crossing erasures.
- **NetWare 3.12 Faithful:** original single red snake, live aggregate CPU, fixed geometry and historical crossing gaps.
- **NetWare 3.12 Customizable:** retains widescreen expansion, colors, character sizes, speed, crossing protection and demo load sweep.

Both Faithful modes use an 80×25 grid in a centered, uniformly scaled 640×480 logical VGA viewport. The 640×400 text raster has 40 virtual blank scanlines above and below. Customizable settings do not alter either Faithful simulation. Each display is an independent console; CPU samples are shared within a host process.

The 4.2 snakes start from column 38, row 12 (zero based), two characters wide, staggered by four simulation intervals per CPU. The nominal rate is 18.2 passes/second, supported by the supplied startup recording. CPU 31 first draws about 6.8 seconds after CPU 0. Their trails change length and motion with each CPU's utilization; they are not recolored copies of the 3.12 snake.

Character codes DB/B2/B1/B0 and the erase space are verified against the supplied kernel and NWSNUT instructions. Rendering uses CP437-like density masks and conventional VGA RGB colors. Exact historical font-ROM pixels, DAC colors and scheduler jitter are not claimed. See [the 4.2 notes](docs/NETWARE42.md) for evidence and adaptation boundaries.

## Build, preview and install

Requires macOS 13+ and Apple Command Line Tools. Builds target the compiling Mac's architecture. Locally ad-hoc signed; not Developer ID signed or notarized.

```sh
./build-macos.sh
open build/NetWareSnakePreview.app
```

In the preview, press **Command-comma**, select **NetWare 4.2 Faithful**, then **Save**. The processor setting shows how many host CPUs will be represented. The original 3.12 selection remains the default for existing preferences.

After checking the preview, quit System Settings and run:

```sh
./install-macos.sh
```

The installer checks v0.4.0/build 13 before replacing the saver and backs up the prior one as `~/Library/Screen Savers/NetWareSnake.previous.saver`. Building alone does not install anything. Options displays the version/build of the actual loaded bundle. Diagnostics remain opt-in; normal operation logs no animation frames or CPU samples.

## Validation

```sh
./tools/run-core-tests.sh       # portable tests, including existing 3.12 parity
./tools/run-macos-tests.sh      # also Mach sampler fixtures, sanitizers, build/signatures
```

This release passed 21 regression tests, the native per-CPU sampling fixtures, 160,000 sanitized engine passes plus 20,000 session intervals, native compilation and signature verification. The integrated 4.2 engine also passed 38,080 differential passes against original MONITOR instructions, 20,000 RNG outputs, and 320 original worker passes. Original proprietary binaries are not distributed. The automated preview-launch inspection timed out on the build host, so the new settings sheet and animation still need visual confirmation on the user's Mac.

Suggested visual check: select 4.2, save, watch the colors emerge from the center in sequence, and increase host CPU load. Check both 3.12 modes afterward. On hosts with 32 or more logical CPUs, compare 31 versus 32 with the checkbox. Confirm the footer reads **v0.4.0 · build 13**. If the system saver retains an old build, quit and reopen System Settings after installation.
