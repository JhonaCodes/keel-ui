#!/usr/bin/env python3
"""Validate the glibc floor of every bundled ELF, including prebuilt plugins."""

import argparse
import re
import subprocess


def version_tuple(value):
    return tuple(map(int, value.split(".")))


def glibc_requirement(version_info):
    versions = re.findall(r"\bGLIBC_(\d+\.\d+(?:\.\d+)?)\b", version_info)
    return max(versions, key=version_tuple) if versions else "0.0"


def declare_glibc(dependencies, required):
    match = re.search(r"\blibc6 \(>= ([0-9.]+)\)", dependencies)
    if not match:
        raise ValueError("dpkg-shlibdeps did not declare the libc6 dependency")
    floor = max((match[1], required), key=version_tuple)
    return dependencies[:match.start()] + f"libc6 (>= {floor})" + dependencies[match.end():]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dependencies", required=True)
    parser.add_argument("binaries", nargs="+")
    args = parser.parse_args()
    host = subprocess.check_output(["getconf", "GNU_LIBC_VERSION"], text=True).split()[1]
    required = "0.0"
    for binary in args.binaries:
        info = subprocess.check_output(["readelf", "--version-info", binary], text=True)
        floor = glibc_requirement(info)
        if version_tuple(floor) > version_tuple(host):
            parser.error(f"{binary} requires GLIBC_{floor}, but the build host has {host}")
        required = max((required, floor), key=version_tuple)
    print(declare_glibc(args.dependencies, required))


if __name__ == "__main__":
    main()
