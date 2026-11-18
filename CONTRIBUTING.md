# Contributing

Bug reports should include the saver version/build, macOS version, mode and
display arrangement. Review diagnostic reports before sharing them. Report
security issues privately using [SECURITY.md](SECURITY.md).

Keep changes focused and explain the resulting behavior and validation in the
pull request. Historical-engine changes should preserve the reference tests;
document deliberate modern adaptations separately.

## Checks

```sh
./tools/run-core-tests.sh
./tools/run-macos-tests.sh     # macOS with Command Line Tools; includes core tests
./tools/check-secrets.sh      # requires Gitleaks 8.30.1 on PATH
```

The secret check scans reachable Git history and staged/unstaged tracked changes.
Stage new files before running it so they are included. `GITLEAKS` can point to
an alternate scanner executable. Scan output redacts detected secret values.
If a real credential is committed, revoke it before discussing history cleanup;
deleting the current file does not remove it from Git history.

CI runs portable tests and the history scan with read-only repository access.
It does not sign, install or publish releases. Native AppKit rendering and actual
screen saver activation still require Mac testing.

## Reference inputs

Keep proprietary NetWare binaries in the ignored `reference-inputs/` directory
or outside the checkout. Do not attach them to issues, pull requests or releases.
The optional original-instruction checks require your own matching images; see
[the research notes](docs/NETWARE42.md). Ordinary regression tests do not require
those inputs or Unicorn.

Signing identities stay in Keychain. Do not commit passwords, Keychain exports,
private keys, notarization credentials or local release logs. The ignored
`.env.example` naming exception is for empty/example values only.

## Formatting

Use readable blocks rather than multiple statements on one line. The cleaned
Modern adapter uses `.clang-format` (clang-format 19.1.7), and the Python research
harnesses and release tooling use Black 25.1.0 with its default line length.
These are optional development tools, not runtime dependencies. Avoid changing
recovered constants or algorithm behavior while reformatting research code.

## Maintainer workflow

Contributors use pull requests. Maintainer changes to `main` should pass the same
checks and keep published tags and assets immutable. Branch protection is not
currently enforced; this cleanup does not change repository access or visibility.
Before enabling required checks, confirm their job names and that the maintainer
can still complete releases. Signed preparation requires a clean checkout.

See [the release procedure](docs/MACOS-RELEASE.md) for signing and publishing.
