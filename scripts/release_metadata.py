#!/usr/bin/env python3
"""Resolve a stable release from pubspec; CI never bumps the tagged source."""

import argparse
import json
import os
from pathlib import Path
import re


def release_metadata(pubspec, tag=None):
    matches = re.findall(
        r"^version:\s*((?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*))"
        r"\+([1-9]\d*)\s*$", pubspec, flags=re.MULTILINE
    )
    if len(matches) != 1:
        raise ValueError("pubspec.yaml must have one version: MAJOR.MINOR.PATCH+BUILD")
    version, build = matches[0]
    expected = f"v{version}"
    if tag is not None and tag != expected:
        raise ValueError(f"Tag must be {expected} to match pubspec.yaml")
    return {"version": version, "build": build, "tag": expected}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pubspec", type=Path, default=Path("pubspec.yaml"))
    parser.add_argument("--tag")
    parser.add_argument("--github-output", action="store_true")
    args = parser.parse_args()
    try:
        metadata = release_metadata(args.pubspec.read_text(), args.tag)
    except ValueError as error:
        parser.error(str(error))
    if args.github_output:
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
            output.writelines(f"{key}={value}\n" for key, value in metadata.items())
    print(json.dumps(metadata))


if __name__ == "__main__":
    main()
