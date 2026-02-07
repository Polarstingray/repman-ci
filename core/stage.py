#!/usr/bin/env python3

import os
import json
import argparse
import tempfile
from dotenv import load_dotenv
import sys

WORKING_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(WORKING_DIR)
from core.index import add_version, create_index_mdata, create_pkg_md, get_version, package_name


ENV_FILE = os.path.join(WORKING_DIR, ".env")

load_dotenv(ENV_FILE)

DEFAULT_BUILDER="ubuntu_amd64"
DEFAULT_METADATA_FILE = os.path.join(WORKING_DIR, "metadata", "index.json")
DEFAULT_OUT_DIR = os.path.join(WORKING_DIR, "out")


def parse_builder(builder: str) -> tuple :
    os, arch = builder.split("_")
    return os, arch

def ensure_environment(metadata_file: str, out_dir: str) -> None:
    os.makedirs(os.path.dirname(metadata_file), exist_ok=True)
    os.makedirs(out_dir, exist_ok=True)
    if not os.path.exists(metadata_file):
        with open(metadata_file, "w") as f:
            json.dump({}, f, indent=4)


def safe_write_json(path: str, data) -> None:
    directory = os.path.dirname(path) or "."
    os.makedirs(directory, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(prefix=".tmp_", dir=directory)
    try:
        with os.fdopen(fd, "w") as tmp_file:
            json.dump(data, tmp_file, indent=4)
            tmp_file.flush()
            os.fsync(tmp_file.fileno())
        os.replace(tmp_path, path)
    finally:
        if os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except OSError:
                pass



def update_version(version: str, update_type: str) -> str:
    parts = version.split(".")
    if len(parts) != 3:
        raise ValueError("Version must be in 'major.minor.patch' format")
    major, minor, patch = map(int, parts)
    if update_type == "major":
        major += 1
        minor = 0
        patch = 0
    elif update_type == "minor":
        minor += 1
        patch = 0
    elif update_type == "patch":
        patch += 1
    else:
        raise ValueError("Invalid update type")
    return f"{major}.{minor}.{patch}"


def main():
    parser = argparse.ArgumentParser(description="CI Runner")
    parser.add_argument("name", type=str, help="Name of program being staged.")
    parser.add_argument(
        "update_type",
        type=str,
        choices=["major", "minor", "patch"],
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
    args = parser.parse_args()

    metadata_file = args.metadata_file
    out_dir = args.out_dir

    if args.env:
        load_dotenv(args.env)
    else:
        load_dotenv(ENV_FILE)

    try:
        ensure_environment(metadata_file, out_dir)
        with open(metadata_file, "r") as f:
            metadata = json.load(f)
    except Exception as exc:
        print(f"Failed to initialize environment or read metadata: {exc}")
        raise SystemExit(1)


    op_sys, arch = parse_builder(args.builder)
    version = "1.0.0"
    if args.name not in metadata:
        create_index_mdata(metadata, args.name, version, op_sys, arch) # create version 1
    else :
        curr_version = get_version(metadata, args.name, op_sys, arch)

        # metadata[args.name].get("versions", version)
        print(f"curr version: {curr_version}")
        if curr_version is not None:
            version = update_version(curr_version, args.update_type)
        add_version(metadata, args.name, version, op_sys, arch)

    try:
        safe_write_json(metadata_file, metadata)
    except Exception as exc:
        print(f"Failed to write metadata file: {exc}")
        raise SystemExit(1)

    pkg_md = create_pkg_md(args.name, version, op_sys, arch)
    pkg_name = package_name(args.name, pkg_md)
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
