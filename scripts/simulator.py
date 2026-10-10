"""Select one explicitly requested, available iPhone simulator, or fail."""

import json
import os
from pathlib import Path
import subprocess
import sys
import uuid


def select(devices, name, runtime, identifier=None):
    if identifier:
        identifier = str(uuid.UUID(identifier)).upper()
    matches = [
        device for key, values in devices.items()
        if key.startswith("com.apple.CoreSimulator.SimRuntime.iOS-")
        for device in values
        if device.get("isAvailable") is True
        and (
            device["udid"].upper() == identifier if identifier
            else key == runtime and device["name"] == name
        )
    ]
    if len(matches) != 1:
        raise ValueError(
            f"Expected one available simulator for {identifier or f'{name} / {runtime}'}, found {len(matches)}. "
            "Set SIMULATOR_UDID explicitly or install the requested runtime; tests will not be skipped."
        )
    return matches[0]["udid"]


if __name__ == "__main__":
    try:
        lock = json.loads((Path(__file__).parent / "tool-versions.json").read_text())
        data = subprocess.run(
            ["xcrun", "simctl", "list", "devices", "available", "--json"],
            check=True, stdout=subprocess.PIPE,
        )
        print(select(
            json.loads(data.stdout)["devices"],
            os.environ.get("SIMULATOR_NAME", lock["simulator_name"]),
            os.environ.get("SIMULATOR_RUNTIME", lock["simulator_runtime"]),
            os.environ.get("SIMULATOR_UDID"),
        ))
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
