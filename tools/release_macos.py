#!/usr/bin/env python3
"""Local macOS release pipeline. No credentials or private keys enter the repo."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import plistlib
import platform
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def run(*args, capture=False):
    return subprocess.run(
        [str(x) for x in args],
        cwd=ROOT,
        check=True,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
    )


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def payload_hashes(folder):
    return {
        str(p.relative_to(folder / "payload")): digest(p)
        for p in sorted((folder / "payload").rglob("*"))
        if p.is_file()
    }


def save(folder, state):
    tmp = folder / "release.json.tmp"
    tmp.write_text(json.dumps(state, indent=2) + "\n")
    tmp.replace(folder / "release.json")


def load(folder):
    state = json.loads((folder / "release.json").read_text())
    artifact = folder / state["artifact"]
    if digest(artifact) != state["sha256"]:
        raise RuntimeError(
            "Artifact changed since preparation; rebuild before submitting."
        )
    return state


def credentials():
    profile = os.environ.get("NOTARY_PROFILE")
    if not profile:
        raise RuntimeError(
            "Set NOTARY_PROFILE to an existing notarytool Keychain profile."
        )
    return profile


def sign(path, identity, team=None, runtime=False):
    args = ["codesign", "--force", "--sign", identity]
    args += ["--timestamp"] if team else ["--timestamp=none"]
    if runtime:
        args += ["--options", "runtime"]
    run(*args, path)
    run("codesign", "--verify", "--deep", "--strict", path)
    details = run("codesign", "--display", "--verbose=4", path, capture=True).stderr
    if team and (
        f"TeamIdentifier={team}" not in details
        or "Authority=Developer ID Application:" not in details
    ):
        raise RuntimeError(
            "Signing identity must be Developer ID Application for the requested team."
        )


def disk_image(folder, state, payload=None):
    suffix = "-DEVELOPMENT" if state["development"] else ""
    name = f"NetWareSnake-{state['version']}-build{state['build']}-arm64{suffix}.dmg"
    path = folder / name
    if path.exists():
        raise RuntimeError("DMG already exists; start a fresh preparation directory.")
    run(
        "hdiutil",
        "create",
        "-volname",
        "NetWare Snake" + suffix,
        "-srcfolder",
        payload or folder / "payload",
        "-fs",
        "HFS+",
        "-format",
        "UDZO",
        path,
    )
    run("hdiutil", "verify", path)
    if not state["development"]:
        sign(path, state["identity"], state["team"])
    state.update(artifact=name, sha256=digest(path))
    (folder / (name + ".sha256")).write_text(f"{state['sha256']}  {name}\n")


def accepted(folder, state):
    if not state.get("submission_id"):
        raise RuntimeError("Submit this artifact first.")
    result = run(
        "xcrun",
        "notarytool",
        "info",
        state["submission_id"],
        "--keychain-profile",
        credentials(),
        "--output-format",
        "json",
        capture=True,
    )
    info = json.loads(result.stdout)
    (folder / (state["phase"] + "-status.json")).write_text(result.stdout)
    if info.get("status") != "Accepted":
        raise RuntimeError(
            f"Apple status: {info.get('status')}. Nothing packaged or published."
        )
    run(
        "xcrun",
        "notarytool",
        "log",
        state["submission_id"],
        "--keychain-profile",
        credentials(),
        folder / (state["phase"] + "-notary-log.json"),
    )


def prepare(development):
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        raise RuntimeError(
            "This first distribution targets native Apple Silicon macOS builds."
        )
    identity, team = os.environ.get("SIGN_IDENTITY"), os.environ.get("TEAM_ID")
    if not development and (not identity or not team):
        raise RuntimeError(
            "Set SIGN_IDENTITY and TEAM_ID, or use development for offline packaging."
        )
    source_dirty = bool(run("git", "status", "--porcelain", capture=True).stdout)
    if source_dirty and not development:
        raise RuntimeError(
            "Signed release preparation requires a clean checkout. Commit changes first."
        )
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    folder = ROOT / "build" / "releases" / stamp
    folder.mkdir(parents=True)
    with (folder / "checks.log").open("w") as log:
        subprocess.run(
            ["./tools/run-macos-tests.sh"],
            cwd=ROOT,
            stdout=log,
            stderr=subprocess.STDOUT,
            check=True,
        )
    payload = folder / "payload"
    payload.mkdir()
    metadata = []
    for bundle in ("NetWareSnake.saver", "NetWareSnakePreview.app"):
        source = ROOT / "build" / bundle
        info = plistlib.loads((source / "Contents/Info.plist").read_bytes())
        metadata.append((info["CFBundleShortVersionString"], info["CFBundleVersion"]))
        architecture = run(
            "lipo",
            "-archs",
            source / "Contents/MacOS" / info["CFBundleExecutable"],
            capture=True,
        ).stdout.strip()
        if architecture != "arm64":
            raise RuntimeError(f"Unexpected binary architecture: {architecture}")
        run("ditto", source, payload / bundle)
        sign(
            payload / bundle,
            "-" if development else identity,
            None if development else team,
            runtime=True,
        )
    if metadata[0] != metadata[1]:
        raise RuntimeError("Saver and preview version/build differ.")
    for file in ("LICENSE", "CHANGELOG.md"):
        shutil.copy2(ROOT / file, payload / file)
    shutil.copy2(ROOT / "packaging/macos/START-HERE.txt", payload / "START-HERE.txt")
    shutil.copy2(ROOT / "docs/PROVENANCE.md", payload / "PROVENANCE.md")
    state = dict(
        version=metadata[0][0],
        build=metadata[0][1],
        development=development,
        identity=None if development else identity,
        team=None if development else team,
        source_commit=run("git", "rev-parse", "HEAD", capture=True).stdout.strip(),
        source_dirty=source_dirty,
        phase="development" if development else "bundles",
        notarized=False,
    )
    notice = (
        "DEVELOPMENT PREVIEW: ad-hoc signed; NOT notarized. Not a public release."
        if development
        else "Developer ID signed release candidate. Apple notarization and clean-Mac validation are pending."
    )
    (payload / "RELEASE-STATUS.txt").write_text(
        f"NetWare Snake {state['version']} / build {state['build']}\n{notice}\n"
    )
    if development:
        disk_image(folder, state)
    else:
        state["artifact"] = "signed-bundles.zip"
        run(
            "ditto",
            "-c",
            "-k",
            "--sequesterRsrc",
            "--keepParent",
            payload,
            folder / state["artifact"],
        )
        state["sha256"] = digest(folder / state["artifact"])
    state["payload_hashes"] = payload_hashes(folder)
    save(folder, state)
    print(f"Prepared: {folder}\nArtifact: {folder / state['artifact']}")
    return folder


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "command",
        choices=["development", "prepare", "submit", "status", "package", "finalize"],
    )
    parser.add_argument("directory", nargs="?", type=Path)
    args = parser.parse_args()
    if args.command in ("development", "prepare"):
        if args.directory:
            parser.error("Preparation creates a fresh directory automatically.")
        prepare(args.command == "development")
        return
    if not args.directory:
        parser.error("Supply the preparation directory printed by prepare.")
    folder = args.directory.resolve()
    state = load(folder)
    if state["development"]:
        raise RuntimeError(
            "Development artifacts cannot be submitted or promoted. Run prepare with Developer ID."
        )
    if args.command == "submit":
        if state.get("submission_id"):
            raise RuntimeError(
                "Already submitted; use status. Do not submit duplicate requests."
            )
        result = run(
            "xcrun",
            "notarytool",
            "submit",
            folder / state["artifact"],
            "--keychain-profile",
            credentials(),
            "--output-format",
            "json",
            capture=True,
        )
        response = json.loads(result.stdout)
        (folder / (state["phase"] + "-submission.json")).write_text(result.stdout)
        state["submission_id"] = response["id"]
        save(folder, state)
        print(
            "Submitted:",
            state["submission_id"],
            "\nRun status later; this command does not wait or publish.",
        )
    elif args.command == "status":
        if not state.get("submission_id"):
            raise RuntimeError("Submit first.")
        run(
            "xcrun",
            "notarytool",
            "info",
            state["submission_id"],
            "--keychain-profile",
            credentials(),
        )
    elif args.command == "package":
        if state["phase"] != "bundles":
            raise RuntimeError("Package requires the accepted signed-bundles ZIP.")
        if payload_hashes(folder) != state["payload_hashes"]:
            raise RuntimeError(
                "Staged payload changed after signing/notarization submission; prepare again."
            )
        accepted(folder, state)
        # Keep the submitted payload immutable so packaging can be retried.
        with tempfile.TemporaryDirectory(prefix="package-", dir=folder) as work:
            payload = Path(work) / "payload"
            run("ditto", folder / "payload", payload)
            run("xcrun", "stapler", "staple", payload / "NetWareSnakePreview.app")
            run("xcrun", "stapler", "validate", payload / "NetWareSnakePreview.app")
            # .saver is carried in the final stapled DMG; stapler doesn't
            # support stapling a .saver directly. Field validation is required.
            (payload / "RELEASE-STATUS.txt").write_text(
                f"NetWare Snake {state['version']} / build {state['build']}\nDeveloper ID signed. Contents accepted by Apple notarization.\nFinal DMG acceptance and clean-Mac validation are recorded with the release.\n"
            )
            disk_image(folder, state, payload)
        state.update(phase="dmg", bundles_submission_id=state.pop("submission_id"))
        save(folder, state)
        print("DMG created. Run submit again, then status, then finalize.")
    elif args.command == "finalize":
        if state["phase"] != "dmg":
            raise RuntimeError("Package and submit the DMG first.")
        accepted(folder, state)
        artifact = folder / state["artifact"]
        run("xcrun", "stapler", "staple", artifact)
        state.update(sha256=digest(artifact), notarized=False)
        save(folder, state)
        run("xcrun", "stapler", "validate", artifact)
        run("codesign", "--verify", "--strict", artifact)
        run(
            "spctl",
            "--assess",
            "--type",
            "open",
            "--context",
            "context:primary-signature",
            "--verbose=2",
            artifact,
        )
        state.update(notarized=True, sha256=digest(artifact))
        (folder / (state["artifact"] + ".sha256")).write_text(
            f"{state['sha256']}  {state['artifact']}\n"
        )
        save(folder, state)
        print(
            "Notarized and stapled. Complete the clean-Mac checklist before publishing:",
            artifact,
        )


if __name__ == "__main__":
    try:
        main()
    except (
        RuntimeError,
        subprocess.CalledProcessError,
        OSError,
        ValueError,
        KeyError,
    ) as exc:
        print(f"Release stopped: {exc}", file=sys.stderr)
        if isinstance(exc, subprocess.CalledProcessError) and exc.stderr:
            print(exc.stderr, file=sys.stderr)
        sys.exit(1)
