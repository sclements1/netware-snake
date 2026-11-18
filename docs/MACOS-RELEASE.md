# macOS release procedure

The first distribution targets Apple Silicon, macOS 13+. Development packaging
works offline. Public distribution requires a valid Developer ID Application
identity, Apple notarization credentials, and successful field validation.
No signing credentials, certificates, private keys or account details belong in
this repository. The scripts never install a saver or publish a GitHub release.

## Offline rehearsal

Run `./tools/release-macos.sh development` from the checkout. It runs the macOS
tests, builds both bundles, copies them into a fresh staging directory, applies
ad-hoc hardened-runtime signatures, and makes a read-only compressed DMG.
The volume, filename and RELEASE-STATUS.txt explicitly mark it DEVELOPMENT and
not notarized. Do not distribute it as the signed release.

Open the DMG, check START-HERE.txt and try the preview. Actual installation and
upgrade checks are manual; creating a DMG does not establish those results.
A normal Gatekeeper rejection of an unnotarized development image is expected.
Do not disable Gatekeeper or strip quarantine attributes to claim validation.

## Signing and notarization

1. Obtain a Developer ID Application certificate and private key in your local
   login Keychain. A Developer ID Installer certificate is unnecessary for a DMG
   with the standard .saver installation flow; it would be needed for a signed
   .pkg installer.
2. Configure a local notarytool Keychain profile. Use its interactive credential
   setup rather than placing a password in a script or shell history:
   `xcrun notarytool store-credentials netware-snake-notary`
3. Set the non-secret release parameters in your shell:

   ```sh
   export SIGN_IDENTITY='Developer ID Application: YOUR NAME (YOURTEAMID)'
   export TEAM_ID='YOURTEAMID'
   export NOTARY_PROFILE='netware-snake-notary'
   ```

4. Run `./tools/release-macos.sh prepare`. It runs tests, builds, signs with a
   secure timestamp and hardened runtime, checks the team, and stages a signed
   ZIP. Signed preparation requires a clean checkout; commit source changes first.
   Copy the output directory path; use it for each command below.
5. Run `./tools/release-macos.sh submit build/releases/DIRECTORY` to upload the
   signed ZIP. This explicitly transmits the compiled software and bundled docs
   to Apple's notarization service. It returns a submission ID without waiting.
6. Run `./tools/release-macos.sh status build/releases/DIRECTORY` later. If Apple
   reports Invalid, inspect the notarization log and rebuild after fixing the
   issue. Retrieve the log with `xcrun notarytool log SUBMISSION-ID --keychain-profile "$NOTARY_PROFILE" notary-log.json`. Do not repeatedly submit the same pending request.
7. Once Accepted, run `./tools/release-macos.sh package build/releases/DIRECTORY`.
   It downloads the Apple log, staples the preview app's ticket, creates the DMG
   and signs the DMG. The .saver is included in the accepted archive; stapler
   does not support .saver bundles directly. Its installation/offline behavior
   must be checked in the screen saver host on a clean Mac.
8. Run `submit` and then `status` again for the new DMG. Once Accepted, run
   `./tools/release-macos.sh finalize build/releases/DIRECTORY` to staple and
   validate the DMG, assess it with Gatekeeper, and compute its final checksum.

The two notarization stages let the preview carry its own ticket after being
copied out of the DMG. The DMG is the final distribution container for the saver.
The scripts stop on errors, retain logs and submission IDs, and refuse to
promote a development artifact or an artifact whose checksum has changed.
The full Apple-backed flow passed for v0.7.3/build 19 and v0.7.4/build 20; see the release validation
record. Each new artifact still requires its own acceptance and validation.
The payload must not be changed between prepare and package.

## Clean-Mac acceptance checklist

Record actual results in [MACOS-RELEASE-TESTING.md](MACOS-RELEASE-TESTING.md). Use a second Mac, or a clean
user account for preliminary checks; the current development account alone is
not proof of a clean installation.

- Download the final DMG using a browser, preserving normal quarantine metadata.
- Confirm DMG opens with normal macOS security settings.
- Launch the preview from the image; check Settings and all three modes.
- Copy preview to Applications; eject DMG; launch the copied app again.
- Double-click the saver, install for the current user, then select it in System
  Settings. Confirm version/build footer and a real full-screen activation.
- Test cancellation and saving preferences, idle activation, repeated starts,
  sleep/wake, and quitting/reopening Settings.
- Test all connected displays, including negative/staggered layouts. Verify
  Unified Desktop seams in the actual system saver, not only the preview.
  Separate host processes currently do not share simulation state.
- Test static wallpaper and fallback behavior for dynamic/unavailable images.
- Install over the preceding build. Confirm the new footer, actual host build tag and retained settings.
  If the host still runs the preceding bundle, quit Settings and restart the Mac
  before retesting.
  Keep the preceding download for rollback; the GUI installer makes no backup.
- On a clean account without cached tickets, test offline installation/launch
  from the final stapled DMG. Record saver behavior separately from preview.
- Remove the user-installed saver through Finder and remove the preview app.
  Confirm neither starts afterward. Preferences intentionally remain.

## Publishing

Record completed checks and any explicitly accepted skips before creating a
versioned GitHub Release. For v0.7.3, clean-machine offline testing was explicitly
skipped; it must not be described as passed. Attach
**only** the finalized DMG, matching .sha256 file, and suitable release notes.
Use a new version/build whenever executable content changes after a published build. The current signed release is v0.7.4/build 20; v0.7.3/build 19 remains available for rollback.
Do not silently replace old published assets. Do not upload staging ZIPs,
Keychain exports, notary credentials or the local signing environment.
Signing/packaging changes in this checkout do not change the animation version.

GitHub Actions release automation is a later step: first prove this local
workflow with the real identity, then use an approval-protected release job.

References: [Developer ID](https://developer.apple.com/developer-id/),
[custom notarization workflows](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow),
[notarization requirements](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
