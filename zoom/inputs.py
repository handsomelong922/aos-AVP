"""Fetch immutable upstream inputs and verify exact per-ABI native parity."""
import hashlib
from pathlib import Path
import re
import struct
import subprocess
import sys
import xml.etree.ElementTree as ET
import zipfile

BASE = "https://github.com/nova-video-player"
VERSION = "v6.6.5"
MANIFEST_SHA = "3f44be0bf07634b469cde54f37b47421735f88fd191d7ac3afbfbd3f9c0aa61c"
SOURCE = {"AVP": "aos-AVP", "Video": "aos-Video", "MediaLib": "aos-MediaLib",
          "FileCoreLibrary": "aos-FileCoreLibrary"}
APK_HASH = {
    "armeabi-v7a": "9fb146566d8fb70ec5ed03ea180aa10abf294eea7a52a4eafc17634eb20e7143",
    "arm64-v8a": "e0ffda4c5f3795d75e89b3c7a8c6da792839ebd21dcb46b50cf3248c3d9157b9",
}
DEPENDENCY_LIBS = {"libsentry.so", "libsentry-android.so"}


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def sha(path):
    with path.open("rb") as f:
        return hashlib.file_digest(f, "sha256").hexdigest()


def run(*args):
    return subprocess.check_output(args, text=True).strip()


def native(apk, abi):
    with zipfile.ZipFile(apk) as z:
        items = [i for i in z.namelist() if i.startswith("lib/") and i.endswith(".so")]
        require(len(items) == len(set(items)) == 22, f"{apk}: expected 22 unique .so files")
        libs = {}
        for i in items:
            match = re.fullmatch(r"lib/([^/]+)/(lib[-\w.]+\.so)", i)
            require(match and match[1] == abi, f"{apk}: unexpected native path: {i}")
            data = z.read(i)
            klass, machine = (2, 183) if abi == "arm64-v8a" else (1, 40)
            require(data[:6] == b"\x7fELF" + bytes((klass, 1))
                    and struct.unpack_from("<H", data, 18)[0] == machine, f"{apk}: invalid ELF {i}")
            libs[match[2]] = data
    return libs


def prepare(root, work):
    manifest = root / "manifest.xml"
    require(sha(manifest) == MANIFEST_SHA, "Official manifest hash mismatch")
    manifest_projects = {p.attrib["path"]: p.attrib for p in ET.parse(manifest).findall("project")}
    for directory, repo in SOURCE.items():
        p = manifest_projects[directory]
        rev = p["revision"]
        require(p["name"] == repo and re.fullmatch(r"[a-f0-9]{40}", rev), "Invalid source pin")
        dest = work / directory
        dest.mkdir()
        git = ("git", "-C", str(dest))
        run(*git, "init", "--quiet")
        run(*git, "fetch", "--quiet", "--depth=1", f"{BASE}/{repo}.git", rev)
        run(*git, "-c", "core.hooksPath=/dev/null", "checkout", "--quiet", "--detach", "FETCH_HEAD")
        require(run(*git, "rev-parse", "HEAD") == rev, f"Wrong source at {directory}")
    for abi, expected in APK_HASH.items():
        name = f"org.courville.nova-2674922-6.6.5-20261111.1224-{abi}-release.apk"
        dest = work / f"{abi}-official.apk"
        run("curl", "--proto", "=https", "--proto-redir", "=https", "-fsSL", "--retry", "3",
            "--max-time", "300", "-o", str(dest), f"{BASE}/aos-AVP/releases/download/{VERSION}/{name}")
        require(sha(dest) == expected, f"Official release APK hash mismatch: {abi}")
        libs = native(dest, abi)
        require(DEPENDENCY_LIBS | {"libfilecoreutils.so", "libavos.so"} <= libs.keys(), "Missing native library")
        for library, data in libs.items():
            if library in DEPENDENCY_LIBS:
                continue
            module = "FileCoreLibrary" if library == "libfilecoreutils.so" else "MediaLib"
            target = work / module / "libs" / abi / library
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)


if __name__ == "__main__":
    if sys.argv[1] == "prepare":
        prepare(Path(sys.argv[2]), Path(sys.argv[3]))
    elif sys.argv[1] == "verify":
        work, apk, abi = Path(sys.argv[2]), Path(sys.argv[3]), sys.argv[4]
        official = work / f"{abi}-official.apk"
        require(sha(official) == APK_HASH[abi], "Official APK changed")
        require(native(apk, abi) == native(official, abi), f"Native parity failed: {abi}")
        print(f"{abi}: 22 exact upstream native objects")
    else:
        raise SystemExit("Unknown command")
