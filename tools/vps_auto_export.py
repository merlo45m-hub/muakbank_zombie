#!/usr/bin/env python3
"""vps_auto_export.py — Issue #3: push to GitHub -> VPS auto-exports Android APK.

Watches origin/main. On a new commit it exports from a DEDICATED clone
(/root/muakbank_export) so it never checks out main under the active dev tree
(/root/muakbank_zombie). Idempotent: state file records the last exported SHA.
Silent when nothing changed (cron-friendly).

Env overrides make the whole loop testable without a real 60s APK build:
  MKB_DEV_REPO   repo to read origin URL from      (default /root/muakbank_zombie)
  MKB_EXPORT_DIR dedicated clone                   (default /root/muakbank_export)
  MKB_STATE      last-exported SHA file            (default /root/.hermes/mkb_last_export_sha)
  MKB_BRANCH     branch to watch                   (default main)
  MKB_GODOT      godot binary                     (default /root/Godot_v4.7-stable_linux.x86_64)
  MKB_EXPORT_CMD shell command; %s = apk out path (default real Godot export)
  MKB_APK_OUT    apk output path                  (default /root/builds/muakbank_latest.apk)
  MKB_DRY_RUN    if 1, detect+record but do not export (still prints one line)
"""
import os
import subprocess
import sys

DEV_REPO = os.environ.get("MKB_DEV_REPO", "/root/muakbank_zombie")
EXPORT_DIR = os.environ.get("MKB_EXPORT_DIR", "/root/muakbank_export")
STATE = os.environ.get("MKB_STATE", "/root/.hermes/mkb_last_export_sha")
BRANCH = os.environ.get("MKB_BRANCH", "main")
GODOT = os.environ.get("MKB_GODOT", "/root/Godot_v4.7-stable_linux.x86_64")
APK_OUT = os.environ.get("MKB_APK_OUT", "/root/builds/muakbank_latest.apk")
PHONE_HOST = os.environ.get("MKB_PHONE_HOST", "phone-ssh")
PHONE_DIR = os.environ.get("MKB_PHONE_DIR", "/storage/emulated/0/Download")
PHONE_COPY = os.environ.get("MKB_PHONE_COPY", "1") != "0"  # set 0 to skip the copy leg
DRY = os.environ.get("MKB_DRY_RUN", "0") == "1"
DEFAULT_IMPORT_CMD = (
    f"cd {EXPORT_DIR} && xvfb-run -a {GODOT} --headless --import --path {EXPORT_DIR}"
)
DEFAULT_EXPORT_CMD = (
    f"cd {EXPORT_DIR} && xvfb-run -a {GODOT} --headless "
    f"--export-debug 'Android' --export-path __APK__"
)
IMPORT_CMD = os.environ.get("MKB_IMPORT_CMD", DEFAULT_IMPORT_CMD)
EXPORT_CMD = os.environ.get("MKB_EXPORT_CMD", DEFAULT_EXPORT_CMD)


def run(cmd, timeout=600):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)


def remote_url():
    r = run(f"cd {DEV_REPO} && git remote get-url origin", 30)
    return r.stdout.strip() if r.returncode == 0 else ""


def head_sha(url):
    r = run(f"git ls-remote {url} refs/heads/{BRANCH}", 60)
    if r.returncode != 0:
        return None
    for line in r.stdout.splitlines():
        if line.endswith(f"refs/heads/{BRANCH}"):
            return line.split()[0]
    return None


def last_sha():
    try:
        return open(STATE, encoding="utf-8").read().strip()
    except FileNotFoundError:
        return ""


def record(sha):
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    with open(STATE, "w", encoding="utf-8") as f:
        f.write(sha + "\n")


def ensure_clone(url):
    if os.path.isdir(os.path.join(EXPORT_DIR, ".git")):
        return
    os.makedirs(os.path.dirname(EXPORT_DIR), exist_ok=True)
    r = run(f"git clone --branch {BRANCH} --single-branch {url} {EXPORT_DIR}", 300)
    if r.returncode != 0:
        raise RuntimeError(f"clone failed: {r.stderr.strip()[:300]}")


def sync(url, sha):
    r = run(
        f"cd {EXPORT_DIR} && git fetch origin {BRANCH} && "
        f"git checkout -f {BRANCH} && git reset --hard {sha}", 300
    )
    if r.returncode != 0:
        raise RuntimeError(f"sync failed: {r.stderr.strip()[:300]}")


def valid_apk(path):
    """The deliverable is the APK, not Godot's exit code. Godot 4.7 headless
    aborts (134) at shutdown on a fresh clone's first import even though the
    export succeeded, so validate the artifact itself: non-empty signed zip with
    AndroidManifest.xml / classes.dex / resources.arsc and clean CRC."""
    import zipfile
    try:
        if not os.path.isfile(path) or os.path.getsize(path) < 1024 * 1024:
            return False
        with zipfile.ZipFile(path) as z:
            names = set(z.namelist())
            required = {"AndroidManifest.xml", "classes.dex", "resources.arsc"}
            if not required.issubset(names):
                return False
            return z.testzip() is None
    except (OSError, zipfile.BadZipFile):
        return False


def main():
    url = remote_url()
    if not url:
        print("AUTO_EXPORT ERROR: no origin remote")
        return 2
    sha = head_sha(url)
    if not sha:
        print("AUTO_EXPORT ERROR: cannot read remote HEAD")
        return 2
    if sha == last_sha():
        return 0  # silent when healthy

    if DRY:
        print(f"AUTO_EXPORT DRY new_sha={sha[:12]} would export")
        record(sha)
        return 0

    ensure_clone(url)
    sync(url, sha)
    # Import is best-effort: Godot's first-import headless exit code is unreliable
    # (see valid_apk docstring). Remove the old APK so a stale file can't pass.
    try:
        os.remove(APK_OUT)
    except FileNotFoundError:
        pass
    imp = run(IMPORT_CMD.replace("__APK__", APK_OUT), 300)
    exp = run(EXPORT_CMD.replace("__APK__", APK_OUT), 900)
    if valid_apk(APK_OUT):
        record(sha)
        # Final leg of #3: copy the APK to the phone's Download over the WireGuard
        # mesh. Best-effort: a copy failure is reported but does not un-record the
        # successful export (avoids a re-export every 10 min on a flaky tunnel).
        copy_note = "copy_skipped"
        if PHONE_COPY:
            c = run(
                f"scp -o BatchMode=yes -o ConnectTimeout=8 {APK_OUT} "
                f"{PHONE_HOST}:{PHONE_DIR}/muakbank_latest.apk", 180
            )
            copy_note = "copy_ok" if c.returncode == 0 else "copy_failed"
        print(f"AUTO_EXPORT OK sha={sha[:12]} apk={APK_OUT} "
              f"bytes={os.path.getsize(APK_OUT)} (import_rc={imp.returncode} "
              f"export_rc={exp.returncode} {copy_note})")
        return 0
    print(f"AUTO_EXPORT FAIL sha={sha[:12]} import_rc={imp.returncode} "
          f"export_rc={exp.returncode}: {(exp.stderr or exp.stdout or imp.stderr).strip()[:300]}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
