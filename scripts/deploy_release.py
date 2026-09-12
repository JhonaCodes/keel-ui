#!/usr/bin/env python3
"""Create a signed release tag, watch both builds, and download the installers."""

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

from release_metadata import release_metadata

ROOT = Path(__file__).resolve().parents[1]


def run(*args, live=False):
    result = subprocess.run(args, cwd=ROOT, text=True, capture_output=not live)
    if result.returncode:
        detail = "" if live else (result.stderr or result.stdout).strip()
        raise RuntimeError(f"Falló {args[0]} {args[1]}: {detail}")
    return "" if live else result.stdout.strip()


def api(repository, path):
    return json.loads(run("gh", "api", f"repos/{repository}/{path}"))


def installer_names(version):
    return [f"Keel-{version}-macos-universal.dmg", f"keel_{version}_amd64.deb",
            f"Keel-{version}-linux-x64.tar.gz", "latest.json", "SHA256SUMS.txt"]


def validate_assets(release, version):
    if release["isDraft"] or release["tagName"] != f"v{version}":
        raise RuntimeError("La release todavía no es pública o tiene otro tag.")
    assets = {asset["name"]: asset for asset in release["assets"]}
    for name in installer_names(version):
        if name not in assets or assets[name]["size"] <= 0:
            raise RuntimeError(f"Falta el instalador publicado: {name}")


def verify_downloads(directory, version):
    checksums = {}
    for line in (directory / "SHA256SUMS.txt").read_text().splitlines():
        match = re.fullmatch(r"([a-f0-9]{64})  (.+)", line)
        if not match or match[2] in checksums:
            raise RuntimeError("El archivo de checksums es inválido.")
        checksums[match[2]] = match[1]
    expected = installer_names(version)[:-1]
    if set(checksums) != set(expected):
        raise RuntimeError("Los checksums no corresponden a todos los instaladores.")
    for name in expected:
        with (directory / name).open("rb") as artifact:
            digest = hashlib.file_digest(artifact, "sha256").hexdigest() if hasattr(hashlib, "file_digest") else None
            if digest is None:
                hasher = hashlib.sha256()
                for chunk in iter(lambda: artifact.read(1024 * 1024), b""):
                    hasher.update(chunk)
                digest = hasher.hexdigest()
        if digest != checksums[name]:
            raise RuntimeError(f"Checksum incorrecto: {name}")


def verified_tag(repository, tag):
    ref = api(repository, f"git/ref/tags/{tag}")
    if ref["object"]["type"] != "tag":
        raise RuntimeError("El tag remoto no es un tag anotado y firmado.")
    verification = api(repository, f"git/tags/{ref['object']['sha']}")["verification"]
    if not verification["verified"]:
        raise RuntimeError(f"GitHub no verifica la firma del tag: {verification['reason']}")


def wait_and_download(repository, tag, version, commit, resume):
    print(f"Buscando la ejecución de {tag} en Actions…", flush=True)
    selected = None
    for _ in range(30):
        runs = json.loads(run("gh", "run", "list", "--repo", repository,
                              "--workflow", "release.yml", "--branch", tag,
                              "--event", "push", "--commit", commit,
                              "--json", "databaseId,status,conclusion,url", "--limit", "5"))
        if runs:
            selected = runs[0]
            break
        time.sleep(4)
    if not selected:
        raise RuntimeError(f"Actions no inició. Revisa GitHub y ejecuta ./scripts/deploy.sh --resume {tag}.")
    run_id = str(selected["databaseId"])
    print(selected["url"], flush=True)
    if resume and selected["status"] == "completed" and selected["conclusion"] != "success":
        run("gh", "run", "rerun", run_id, "--repo", repository, "--failed", live=True)
    try:
        run("gh", "run", "watch", run_id, "--repo", repository, "--exit-status", "--interval", "15", live=True)
    except RuntimeError as error:
        raise RuntimeError(f"Actions no terminó correctamente: {selected['url']}. "
                           f"Para reintentar el mismo código: ./scripts/deploy.sh --resume {tag}") from error
    release = json.loads(run("gh", "release", "view", tag, "--repo", repository,
                             "--json", "isDraft,tagName,assets,url"))
    validate_assets(release, version)
    destination = ROOT / "build" / "downloads" / tag
    destination.mkdir(parents=True, exist_ok=True)
    run("gh", "release", "download", tag, "--repo", repository,
        "--dir", str(destination), "--clobber", live=True)
    verify_downloads(destination, version)
    print(f"\nRelease pública: {release['url']}\nInstaladores verificados: {destination}")
    for asset in release["assets"]:
        if asset["name"] in installer_names(version):
            print(f"  {asset['name']}: {asset['url']}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verificar requisitos y mostrar la próxima versión, sin publicar")
    parser.add_argument("--version", help="Versión nueva X.Y.Z; por defecto aplica el incremento del proyecto")
    parser.add_argument("--resume", metavar="TAG", help="Retomar una publicación sin crear otro tag")
    args = parser.parse_args()
    if args.resume and args.version:
        parser.error("--resume y --version no se pueden combinar")
    for command in ("git", "gh", "dart", "gpg"):
        if not shutil.which(command):
            raise RuntimeError(f"Falta instalar {command}.")
    if run("git", "status", "--porcelain"):
        raise RuntimeError("Guarda los cambios del proyecto en un commit antes de desplegar.")
    branch = run("git", "branch", "--show-current")
    if branch != "main":
        raise RuntimeError("Ejecuta el despliegue desde main.")
    repository = run("gh", "repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner")
    origin = run("git", "remote", "get-url", "origin")
    if origin.removesuffix(".git") not in (f"git@github.com:{repository}", f"https://github.com/{repository}"):
        raise RuntimeError("origin y el repositorio de gh no coinciden en github.com.")
    run("gh", "auth", "status")
    run("git", "fetch", "origin", "main")
    run("git", "merge-base", "--is-ancestor", "origin/main", "HEAD")
    source = (ROOT / "pubspec.yaml").read_text()
    current = release_metadata(source)
    if args.resume:
        release_metadata(source, args.resume)
        tag, version = args.resume, current["version"]
        run("git", "verify-tag", tag)
        commit = run("git", "rev-parse", f"{tag}^{{commit}}")
        if commit != run("git", "rev-parse", "HEAD"):
            raise RuntimeError("El tag no apunta al commit actual. Una corrección necesita una versión nueva.")
        remote_tag = run("git", "ls-remote", "--tags", "origin", f"refs/tags/{tag}")
        if not remote_tag:
            if args.check:
                print(f"{tag} está firmado localmente y listo para subir. No se publicó.")
                return
            run("git", "push", "--atomic", "origin", "HEAD:refs/heads/main", f"refs/tags/{tag}", live=True)
        elif remote_tag.split()[0] != run("git", "rev-parse", tag):
            raise RuntimeError("El tag remoto difiere del local; no se sobrescribe.")
        verified_tag(repository, tag)
        if not args.check:
            wait_and_download(repository, tag, version, commit, resume=True)
        return
    if run("git", "config", "--get", "commit.gpgsign") != "true":
        raise RuntimeError("Activa commit.gpgsign antes de desplegar; no se publican commits sin firma.")
    signing_key = run("git", "config", "--get", "user.signingkey")
    # Fail promptly if the configured OpenPGP key cannot sign without a prompt.
    probe = subprocess.run(["gpg", "--batch", "--yes", "--local-user", signing_key,
                            "--armor", "--detach-sign"], input=b"Keel release signing check\n",
                           stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=15)
    if probe.returncode:
        raise RuntimeError("GPG no pudo firmar. Desbloquea tu clave en el agente GPG y reintenta.")
    build = str(int(current["build"]) + 1)
    if args.version:
        proposed = release_metadata(f"version: {args.version}+{build}\n")
    else:
        next_value = run("dart", "run", "tool/release_version.dart", "next", f"{current['version']}+{current['build']}")
        proposed = release_metadata(f"version: {next_value}\n")
    version, tag = proposed["version"], proposed["tag"]
    if tuple(map(int, version.split("."))) <= tuple(map(int, current["version"].split("."))):
        raise RuntimeError("La nueva versión debe ser mayor que la actual.")
    if run("git", "tag", "--list", tag) or run("git", "ls-remote", "--tags", "origin", f"refs/tags/{tag}"):
        raise RuntimeError(f"{tag} ya existe. Usa --resume para retomarlo o una versión nueva.")
    print(f"Keel {version} (build {proposed['build']}) → {tag}\nmacOS universal + Linux x86_64\nRepositorio: {repository}", flush=True)
    if args.check:
        print("Requisitos correctos. No se modificó la versión ni se creó/publicó ningún tag.")
        return
    replacement = f"version: {version}+{proposed['build']}"
    updated = re.sub(r"^version:[^\n]+", replacement, source, count=1, flags=re.MULTILINE)
    (ROOT / "pubspec.yaml").write_text(updated)
    run("git", "commit", "--only", "pubspec.yaml", "-m", f"Release Keel {version}", live=True)
    if run("git", "log", "-1", "--format=%G?") != "G":
        raise RuntimeError("El commit de versión no tiene una firma válida; no se subió.")
    run("git", "tag", "-s", tag, "-m", f"Keel {version} — macOS and Linux", live=True)
    run("git", "verify-tag", tag, live=True)
    commit = run("git", "rev-parse", "HEAD")
    print(f"Subiendo el commit y el tag firmado {tag}…", flush=True)
    run("git", "push", "--atomic", "origin", "HEAD:refs/heads/main", f"refs/tags/{tag}", live=True)
    verified_tag(repository, tag)
    print(f"GitHub confirmó la firma de {tag}.", flush=True)
    wait_and_download(repository, tag, version, commit, resume=False)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, OSError, subprocess.TimeoutExpired) as error:
        print(f"\nDespliegue detenido: {error}", file=sys.stderr)
        sys.exit(1)
