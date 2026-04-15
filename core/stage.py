#!/usr/bin/env python3

import os
import re
import json
import argparse
from dotenv import load_dotenv
import sys

_lib_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # core/../ = lib/ or root
# Support installed layout (core/ inside lib/) or dev layout (core/ at root)
WORKING_DIR = os.path.dirname(_lib_dir) if os.path.basename(_lib_dir) == "lib" else _lib_dir
sys.path.append(_lib_dir)
from core.index import (
    add_version,
    create_index_mdata,
    create_pkg_md,
    get_version,
    package_name,
    safe_write_json,
    update_version,
)


ENV_FILE = os.path.join(WORKING_DIR, "data", "config.env")

load_dotenv(ENV_FILE)

DEFAULT_BUILDER = os.getenv("DEFAULT_BUILDER", "ubuntu_amd64")
DEFAULT_METADATA_FILE = os.path.join(WORKING_DIR, "metadata", "index.json")
DEFAULT_OUT_DIR = os.path.join(WORKING_DIR, "out")
PKG_URL = os.getenv("GITHUB_REPO", "https://example.com/package")
INITIAL_VERSION = "1.0.0"

SEMVER_RE = re.compile(r'^\d+\.\d+\.\d+$')


def parse_builder(builder: str) -> tuple:
    op_sys, arch = builder.split("_")
    return op_sys, arch

def ensure_environment(metadata_file: str, out_dir: str) -> None:
    os.makedirs(os.path.dirname(metadata_file), exist_ok=True)
    os.makedirs(out_dir, exist_ok=True)
    if not os.path.exists(metadata_file):
        with open(metadata_file, "w") as f:
            json.dump({}, f, indent=4)


def main() -> None:
    parser = argparse.ArgumentParser(description="CI Runner")
    parser.add_argument("name", type=str, help="Name of program being staged.")
    parser.add_argument(
        "update_type",
        type=str,
        choices=["major", "minor", "patch", "new"],
        help="Type of update to apply to the version.",
    )
    parser.add_argument(
        "-b", "--builder",
        type=str,
        default=DEFAULT_BUILDER,
        help="Name of the builder to use for the program.",
    )
    parser.add_argument("-e", "--env", type=str, help="Path to environment file")
    parser.add_argument(
        "--metadata-file",
        dest="metadata_file",
        default=DEFAULT_METADATA_FILE,
        help="Path to metadata JSON file (default: %(default)s)",
    )
    parser.add_argument(
        "--out-dir",
        dest="out_dir",
        default=DEFAULT_OUT_DIR,
        help="Output directory for package metadata (default: %(default)s)",
    )
    parser.add_argument(
        "--version",
        dest="explicit_version",
        default=None,
        metavar="X.Y.Z",
        help="Explicit version override. Skips automatic version bump.",
    )
    parser.add_argument(
        "--notes",
        dest="notes",
        default=None,
        help="Release notes to attach to this version in the index.",
    )
    args = parser.parse_args()

    metadata_file = args.metadata_file
    out_dir = args.out_dir

    if args.env:
        load_dotenv(args.env)

    # Validate explicit version if provided
    explicit_version = None
    if args.explicit_version:
        if not SEMVER_RE.match(args.explicit_version):
            raise SystemExit(
                f"Invalid version '{args.explicit_version}'. Expected X.Y.Z format (e.g. 1.2.3)."
            )
        explicit_version = args.explicit_version

    try:
        ensure_environment(metadata_file, out_dir)
        with open(metadata_file, "r") as f:
            metadata = json.load(f)
    except Exception as exc:
        print(f"Failed to initialize environment or read metadata: {exc}")
        raise SystemExit(1)

    op_sys, arch = parse_builder(args.builder)

    notes = args.notes or None

    if explicit_version:
        version = explicit_version
        pkg_url = f"{PKG_URL}/{args.name}-v{version}"
        if args.name not in metadata:
            create_index_mdata(metadata, args.name, version, op_sys, arch, pkg_url, notes=notes)
        else:
            add_version(metadata, args.name, version, op_sys, arch, pkg_url, notes=notes)
    else:
        version = INITIAL_VERSION
        pkg_url = f"{PKG_URL}/{args.name}-v{version}"
        if args.name not in metadata:
            if args.update_type != "new":
                raise SystemExit(
                    f"Package '{args.name}' is not in the index; "
                    f"use update_type 'new' to register it."
                )
            create_index_mdata(metadata, args.name, version, op_sys, arch, pkg_url, notes=notes)
        else:
            if args.update_type == "new":
                raise SystemExit(
                    f"update_type 'new' is only valid for packages not yet in the index; "
                    f"'{args.name}' already exists. Use major/minor/patch instead."
                )
            curr_version = get_version(metadata, args.name, op_sys, arch)
            if curr_version is not None:
                version = update_version(curr_version, args.update_type)
            pkg_url = f"{PKG_URL}/{args.name}-v{version}"
            add_version(metadata, args.name, version, op_sys, arch, pkg_url, notes=notes)

    try:
        safe_write_json(metadata_file, metadata)
    except Exception as exc:
        print(f"Failed to write metadata file: {exc}")
        raise SystemExit(1)

    pkg_md = create_pkg_md(args.name, version, op_sys, arch)
    pkg_name = package_name(args.name, version, op_sys, arch)
    out_path = os.path.join(out_dir, f"{pkg_name}_md.json")
    try:
        safe_write_json(out_path, pkg_md)
    except Exception as exc:
        print(f"Failed to write output file: {exc}")
        raise SystemExit(1)

    print(f"Program {args.name} has been staged.")
    print(pkg_name)


if __name__ == "__main__":
    main()
