"""Install checksum-pinned validation tools locally, never into the system."""

import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import sys
import tarfile
import tempfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def install(name):
    lock = json.loads((ROOT / "scripts/tool-versions.json").read_text())
    tool = lock["tools"][name]
    host = f"{platform.system()}-{platform.machine()}"
    if host not in tool["assets"]:
        raise ValueError(f"{name} has no pinned release for {host}")
    asset = tool["assets"][host]
    tools = ROOT / "target/ci-tools"
    tools.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=f"{name}-", dir=tools) as work:
        work = Path(work)
        archive = work / "archive"
        request = urllib.request.Request(asset["url"], headers={"User-Agent": "Rook-tool-installer"})
        with urllib.request.urlopen(request, timeout=60) as response, archive.open("wb") as output:
            shutil.copyfileobj(response, output)
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        if digest != asset["sha256"]:
            raise ValueError(f"{name} checksum mismatch; no executable installed")
        extracted = work / "extracted"
        extracted.mkdir()
        if zipfile.is_zipfile(archive):
            with zipfile.ZipFile(archive) as bundle:
                for member in bundle.infolist():
                    if not (extracted / member.filename).resolve().is_relative_to(extracted):
                        raise ValueError(f"{name} archive contains an unsafe path")
                bundle.extractall(extracted)
        else:
            with tarfile.open(archive) as bundle:
                bundle.extractall(extracted, filter="data")
        executable = extracted / asset["executable"]
        if not executable.is_file():
            raise ValueError(f"{name} executable is missing from the verified archive")
        # Retain XcodeGen's adjacent setting presets as well as its executable.
        destination = tools / f"{name}-{tool['version']}"
        destination.mkdir(exist_ok=True)
        shutil.copytree(extracted, destination, dirs_exist_ok=True)
        if name == "xcodegen":
            shutil.copytree(extracted / "xcodegen/share", tools / "share", dirs_exist_ok=True)
        executable = destination / asset["executable"]
        executable.chmod(executable.stat().st_mode | 0o111)
        binaries = tools / "bin"
        binaries.mkdir(exist_ok=True)
        link = binaries / name
        if link.is_symlink():
            link.unlink()
        elif link.exists():
            raise ValueError(f"Refusing to overwrite {link}")
        link.symlink_to(os.path.relpath(executable, binaries))
        print(f"Installed {name} {tool['version']} (verified SHA-256)", file=sys.stderr)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit("Usage: python3 scripts/install-tools.py actionlint shellcheck|xcodegen")
    try:
        for tool_name in sys.argv[1:]:
            install(tool_name)
    except (KeyError, ValueError, OSError, tarfile.TarError, zipfile.BadZipFile) as error:
        sys.exit(str(error))
