#!/usr/bin/env python3

import os
import json
import argparse
import tempfile

WORKING_DIR = os.path.dirname(os.path.abspath(__file__))
OS_DEFAULT = "Ubuntu22"
ARCH_DEFAULT = "x86-64"

DEFAULT_METADATA_FILE = os.path.join(WORKING_DIR, "metadata", "stage.json")
DEFAULT_OUT_DIR = os.path.join(WORKING_DIR, "out")


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

def index_mdata(md: dict) -> dict:
    metadata = {
        "name": md.get("name"),
        "latest": md.get("version"),
        "versions" : {

        }
    }
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


def package_name(name: str, md: dict) -> str:
    return f"{name}_v{md.get('version')}_{md.get('os')}_{md.get('arch')}".lower()


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
        default=OS_DEFAULT,
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

    try:
        ensure_environment(metadata_file, out_dir)
        with open(metadata_file, "r") as f:
            metadata = json.load(f)
    except Exception as exc:
        print(f"Failed to initialize environment or read metadata: {exc}")
        raise SystemExit(1)

    if args.name not in metadata:
        metadata[args.name] = {
            "name": args.name,
            "version": "1.0.0",
            "os": OS_DEFAULT,
            "arch": ARCH_DEFAULT,
            "dependencies": {},
        }
    else:
        curr_version = metadata[args.name].get("version", "1.0.0")
        version = update_version(curr_version, args.update_type)
        metadata[args.name]["version"] = version
        metadata[args.name]["arch"] = ARCH_DEFAULT

    try:
        safe_write_json(metadata_file, metadata)
    except Exception as exc:
        print(f"Failed to write metadata file: {exc}")
        raise SystemExit(1)

    pkg_name = package_name(args.name, metadata[args.name])
    out_path = os.path.join(out_dir, f"{pkg_name}_md.json")
    try:
        safe_write_json(out_path, metadata[args.name])
    except Exception as exc:
        print(f"Failed to write output file: {exc}")
        raise SystemExit(1)

    print(f"Program {args.name} has been staged.")
    print(pkg_name)


if __name__ == "__main__":
    main()
