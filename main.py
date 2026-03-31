#!/usr/bin/env python3

import argparse
import json
import os
import sys
import shutil
from subprocess import run, CalledProcessError
from typing import Optional

from dotenv import load_dotenv

WORKING_DIR = os.path.dirname(os.path.abspath(__file__))
STAGE_SCRIPT = os.path.join(WORKING_DIR, "core", "stage.py")
PUBLISH_PIPELINE = os.path.join(WORKING_DIR, "scripts", "publish_pipeline.sh")
BUILDERS_DIR = os.path.join(WORKING_DIR, "builders")
ENV_FILE = os.path.join(WORKING_DIR, "config.env")

# Allow importing core helpers
sys.path.append(WORKING_DIR)
from core.index import (  # noqa: E402
    add_version,
    create_index_mdata,
    create_pkg_md,
    edit_target,
    get_version,
    package_name,
    safe_write_json,
)

load_dotenv(ENV_FILE)

_index_dir = os.getenv("INDEX_DIR", "metadata")
_index_file = os.getenv("INDEX_FILE", "index.json")
INDEX_PATH = os.path.join(WORKING_DIR, _index_dir, _index_file)


def _load_index(path: str = INDEX_PATH) -> dict:
    if not os.path.exists(path):
        return {}
    with open(path, "r") as f:
        try:
            return json.load(f)
        except json.JSONDecodeError:
            raise SystemExit(f"Metadata file is invalid JSON: {path}")


def _write_index(md: dict, path: str = INDEX_PATH) -> None:
    safe_write_json(path, md)


def cmd_get_index(args: argparse.Namespace) -> int:
    md = _load_index(args.index)
    print(json.dumps(md, indent=4))
    return 0


def cmd_get_builders(_: argparse.Namespace) -> int:
    if not os.path.isdir(BUILDERS_DIR):
        print("No builders directory found.")
        return 0
    builders = []
    for entry in sorted(os.listdir(BUILDERS_DIR)):
        full = os.path.join(BUILDERS_DIR, entry)
        if os.path.isfile(full) and entry.endswith((".yml", ".yaml")):
            builders.append(entry)
        # also surface docker subdir flavors
        if os.path.isdir(full) and entry == "docker":
            for f in sorted(os.listdir(full)):
                if os.path.isfile(os.path.join(full, f)):
                    builders.append(os.path.join("docker", f))
    for b in builders:
        print(b)
    return 0


def _parse_builder(builder: str) -> tuple[str, str]:
    parts = builder.split("_")
    if len(parts) != 2:
        raise SystemExit("Builder must be in the form '<os>_<arch>' e.g., 'ubuntu_amd64'")
    return parts[0], parts[1]


def cmd_get_version(args: argparse.Namespace) -> int:
    md = _load_index(args.index)
    if not args.name:
        raise SystemExit("--name is required")
    if not args.builder:
        raise SystemExit("--builder is required and must be like 'ubuntu_amd64'")
    os_name, arch = _parse_builder(args.builder)
    ver = get_version(md, args.name, os_name, arch)
    if ver is None:
        print("None")
    else:
        print(ver)
    return 0


def cmd_get_env(_: argparse.Namespace) -> int:
    keys = [
        "WORKING_DIR",
        "DEFAULT_BUILDER",
        "DEFAULT_STAGE",
        "GITHUB_REPO",
        "SIG_PASS",
        "INDEX_DIR",
        "INDEX_FILE",
        "PUB_KEY1",
    ]
    for k in keys:
        v = os.getenv(k, "")
        print(f"{k}={v}")
    return 0


def cmd_stage(args: argparse.Namespace) -> int:
    # Proxy to core/stage.py so logic stays single-sourced
    cmd = [sys.executable, STAGE_SCRIPT, args.name, args.update_type]
    if args.builder:
        cmd += ["-b", args.builder]
    if args.env:
        cmd += ["-e", args.env]
    if args.metadata_file:
        cmd += ["--metadata-file", args.metadata_file]
    if args.out_dir:
        cmd += ["--out-dir", args.out_dir]
    try:
        env = os.environ.copy()
        env["PYTHONUNBUFFERED"] = "1"
        run(cmd, check=True, env=env)
        return 0
    except CalledProcessError as exc:
        print(f"stage failed: {exc}")
        return exc.returncode or 1


def cmd_run(args: argparse.Namespace) -> int:
    if not os.path.isfile(PUBLISH_PIPELINE):
        raise SystemExit(f"Pipeline script not found: {PUBLISH_PIPELINE}")
    if shutil.which("stdbuf"):
        cmd = ["stdbuf", "-oL", "-eL", "bash", PUBLISH_PIPELINE, args.project_path, args.update_type]
    else:
        cmd = ["bash", PUBLISH_PIPELINE, args.project_path, args.update_type]
    if args.builder:
        cmd.append(args.builder)
    if args.stage_dir:
        cmd.append(args.stage_dir)
    try:
        run(cmd, check=True)
        return 0
    except CalledProcessError as exc:
        print(f"pipeline failed: {exc}")
        return exc.returncode or 1


def cmd_update(args: argparse.Namespace) -> int:
    # Backward-compatible alias for run
    return cmd_run(args)


def cmd_add_sha256(args: argparse.Namespace) -> int:
    # Update sha256 field for a specific target to its canonical filename
    if not all([args.name, args.version, args.os, args.arch]):
        raise SystemExit("name, version, os, and arch are required")
    md = _load_index(args.index)
    fname = package_name(args.name, args.version, args.os, args.arch, 2)
    ok = edit_target(md, args.name, args.version, args.os, args.arch, "sha256", fname)
    if not ok:
        raise SystemExit("Failed to update sha256 field (missing entry?)")
    _write_index(md, args.index)
    print("updated")
    return 0


def cmd_config(_: argparse.Namespace) -> int:
    editor = os.environ.get("EDITOR", "nano")
    try:
        run([editor, ENV_FILE], check=True)
        return 0
    except CalledProcessError as exc:
        print(f"config edit failed: {exc}")
        return exc.returncode or 1


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Repman CI Runner")
    sub = p.add_subparsers(dest="cmd", required=True)

    # get-index
    sp = sub.add_parser("get-index", help="Print the metadata index JSON")
    sp.add_argument("--index", default=INDEX_PATH, help="Path to index.json (default: %(default)s)")
    sp.set_defaults(func=cmd_get_index)

    # get-builders
    sp = sub.add_parser("get-builders", help="List available builders")
    sp.set_defaults(func=cmd_get_builders)

    # get-version
    sp = sub.add_parser("get-version", help="Get latest version for a name+builder from index")
    sp.add_argument("--index", default=INDEX_PATH, help="Path to index.json (default: %(default)s)")
    sp.add_argument("--name", required=True, help="Package name")
    sp.add_argument("--builder", required=True, help="Builder in form os_arch, e.g. ubuntu_amd64")
    sp.set_defaults(func=cmd_get_version)

    # get-env
    sp = sub.add_parser("get-env", help="Print key environment values")
    sp.set_defaults(func=cmd_get_env)

    # stage
    sp = sub.add_parser("stage", help="Stage a program version (metadata + pkg md)")
    sp.add_argument("name", help="Program name to stage")
    sp.add_argument("update_type", choices=["major", "minor", "patch", "new"], help="Version update type")
    sp.add_argument("-b", "--builder", help="Builder to use (e.g. ubuntu_amd64)")
    sp.add_argument("-e", "--env", help="Path to env file to load")
    sp.add_argument("--metadata-file", help="Path to index.json (override)")
    sp.add_argument("--out-dir", help="Output directory for package metadata")
    sp.set_defaults(func=cmd_stage)

    # run (pipeline)
    sp = sub.add_parser("run", help="Run full publish pipeline for a project")
    sp.add_argument("project_path", help="Path to the project to build and publish")
    sp.add_argument("update_type", choices=["major", "minor", "patch", "new"], help="Version update type")
    sp.add_argument("-b", "--builder", help="Builder to use (e.g. ubuntu_amd64)")
    sp.add_argument("--stage-dir", help="Optional staging/output directory override")
    sp.set_defaults(func=cmd_run)

    # update (alias of run)
    sp = sub.add_parser("update", help="Alias of 'run'")
    sp.add_argument("project_path", help="Path to the project to build and publish")
    sp.add_argument("update_type", choices=["major", "minor", "patch", "new"], help="Version update type")
    sp.add_argument("-b", "--builder", help="Builder to use (e.g. ubuntu_amd64)")
    sp.add_argument("--stage-dir", help="Optional staging/output directory override")
    sp.set_defaults(func=cmd_update)

    # add-sha256
    sp = sub.add_parser("add-sha256", help="Update sha256 field for a specific target")
    sp.add_argument("--index", default=INDEX_PATH, help="Path to index.json (default: %(default)s)")
    sp.add_argument("name", help="Package name")
    sp.add_argument("version", help="Version (e.g., 1.2.3)")
    sp.add_argument("os", help="Target OS (e.g., ubuntu)")
    sp.add_argument("arch", help="Target arch (e.g., amd64)")
    sp.set_defaults(func=cmd_add_sha256)

    # config
    sp = sub.add_parser("config", help="Open config.env in $EDITOR (default nano)")
    sp.set_defaults(func=cmd_config)

    return p


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    rc = args.func(args)  # type: ignore[attr-defined]
    raise SystemExit(rc)


if __name__ == "__main__":
    main()
