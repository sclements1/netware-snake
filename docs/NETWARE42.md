# NetWare 4.2 Faithful: provenance and adapter choices

Recovered from the user's unpacked NetWare 4.2 MONITOR.NLM (MON42U.NLM, SHA-256 `0a1940dbf942abfb02db4c1690336b85454e7efd0656ea3a36cdace2f13f6c69`). `core/nw4_snake.c` is the portable engine; `core/nw4_session.c` supplies modern host policy. Proprietary files are not distributed.

## Preserved instruction behavior

- Shared additive 16-bit, 55-word RNG, original seed words and indices; no per-snake reseeding.
- Zero-based origin (38,12), two adjacent text cells per write, original heading initialization and turn consumption.
- Palette attributes `12,9,10,11,13,7,4,1,2,3,6,14,5,8,15`, repeating every 15 CPUs.
- Eight direction vectors, original boundary-retry table, five cursors and 51-slot history; random heading change after each 40 worker passes.
- CPU percentages 0–11, 12–22, 23–33, 34–55 and 56–100 yield effective history leads 10, 5, 3, 2 and 1. Original fixed-point history updates are preserved instead of scaling geometric length.
- Shared character AND attribute writes, including erasure that can remove another snake's pixels. No collision avoidance or crossing protection.
- Glyph requests 47/46/45/44 resolve to DB/B2/B1/B0, with erase space 20. Confirmed through the supplied SERVER kernel table-copy and NWSNUT lookup instructions.
- First worker pass after 4*p delay calls for processor p, including index 31.

## Explicit modern choices

Represent the first min(host logical CPUs,31) processors by default. Enabling 32 raises only the cap, never synthesizes CPUs. macOS logical CPU counters replace NetWare utilization services. First readings establish a zero baseline; subsequent readings use wrap-safe per-state tick deltas. The saver creates no per-core affinity or stress workload.

Nominal 18.2 intervals/sec is supported by the startup video's approximately 0.2194-second inter-snake spacing and original four-delay rule. Exact kernel timing and scheduler jitter are not reproduced. Simultaneous updates run in ascending CPU index order. All objects initialize in index order before worker steps begin. Multi-display worlds are independent. Another activation clears the screen and palette assignment while preserving the world's shared random sequence; a fresh view/world represents a fresh module lifetime.

The renderer uses verified character codes with CP437-like density masks, conventional VGA RGB colors and the existing centered 640×480 logical presentation. Exact font-ROM pixels and DAC values remain unverified. These limitations affect pixel/timing equivalence, not validated state-machine behavior under a specified schedule.

## Evidence and repeatability

The integrated engine passed 38,080 passes against original x86 instructions. Each compared the full 284-byte state, shared 118-byte RNG state, ordered drawing calls and both full 80×25 planes. Cases cover every percentage, stable bands, transitions, 1/2/4/16/32 snakes, shuffled schedules, alternate screen-type branch, palette cycling and restarts. Separately, 20,000 random outputs and 320 original worker passes match. See `netware42-comparison-results.json`.

Native sanitizer tests add 160,000 low-level passes and 20,000 host-session intervals. Portable tests check caps, all 32 center startup appearances/colors, staggered scheduling, mixed per-CPU loads, activation clearing and RNG continuity. Native sampling tests use controlled Mach counters. Existing 3.12 parity is retained.

Repeat the optional original-instruction suite after installing `tests/netware4_reference/requirements.txt` into a chosen Python environment:

```sh
PYTHON=/path/to/venv/bin/python tools/check-netware4-original.sh /path/to/MON42U.NLM
```

Set `SERVER_IMAGE` and `NWSNUT_IMAGE` to matching unpacked images for real glyph-chain execution. Without these the harness explicitly uses mocked constants. Known source hashes: SERVERU `66b204a974efc5019946d238e74aba61f8c99db78364c6b86bb273c1f2748546`; NWSNUTU `eafbf1f29be65514bcf62f20e5932ad246b4e641627ff0e03472b1fbc81c7988`.

On this restricted Apple Silicon host, stock Unicorn 2.1.4's denied cache-line sysctl falls back to a trapping register read. Included hash-guarded `prepare_unicorn_mac.py` can patch a LOCAL COPY of that library's host cache-line probe to a conservative 64-byte maintenance stride; set `LIBUNICORN_PATH` to that directory. Guest instructions and proprietary images are unchanged. Use stock Unicorn on normal unrestricted hosts. The integrated comparison used the real glyph chain and this documented host workaround.
