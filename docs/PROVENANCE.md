# Provenance and project identity

NetWare Snake is an independent reconstruction of historical screen saver
behavior with modern macOS adaptations. It is not affiliated with or endorsed by
Novell or the owners of the NetWare name. Product names identify the systems
studied; they do not imply ownership of those names.

## Implementation and research

The repository's implementation and documentation are distributed under the MIT
license in `LICENSE`. Original NetWare binaries, font ROMs, installation media
and other third-party software are not included or relicensed by this project.

- **3.12:** `tests/python_reference.py` documents a static reconstruction of
  MONITOR.NLM v1.76 (1993), including code/data-relative offsets. The portable C
  engine is checked against that reference. This checkout does not contain the
  original 3.12 image or an original-instruction runner for it. Recovery details,
  controlled-load video evidence and the 41,600-pass parity boundary are recorded
  in `docs/NETWARE312.md` in the source repo.
- **4.2:** the portable engine reconstructs behavior from the unpacked MONITOR
  image identified by SHA-256
  `0a1940dbf942abfb02db4c1690336b85454e7efd0656ea3a36cdace2f13f6c69`.
  The research retains recovered direction, palette, glyph and RNG constants.
  Optional emulation compares the implementation with instructions from locally
  supplied matching images. Source hashes, comparison boundaries and supporting
  SERVER/NWSNUT evidence are recorded in `docs/NETWARE42.md` in the source repo.
- **Modern and enhanced presentation:** Unified Desktop, wallpaper trails,
  configurable grids/colors, per-CPU macOS sampling and adaptive E/P/S sizing are
  project adaptations. They are not claims about a historical NetWare release.

Rendering uses CP437-like density masks and conventional VGA colors. No original
font ROM or claim of exact DAC reproduction is included. Timing and scheduler
ordering also have documented approximation boundaries.

## Dependencies

Released macOS bundles link system Apple frameworks. Optional original-instruction
research uses Unicorn 2.1.4, installed separately; its library and license are not
part of the release bundles. A hash-guarded helper can patch a local library copy
for restricted Apple Silicon research hosts. That workaround is optional and
does not alter proprietary guest images or ship in the screen saver.

CI downloads Gitleaks separately for secret scanning. Formatting tools and the
scanner are development tools, not bundled runtime dependencies.

Full research notes: https://github.com/sclements1/netware-snake/tree/main/docs
