#!/usr/bin/env python3

import argparse
import getpass
import json
import os
import sys
import shutil
from subprocess import run, CalledProcessError, DEVNULL

from dotenv import load_dotenv

_self_dir = os.path.dirname(os.path.abspath(__file__))
# Support installed layout (main.py in lib/) or dev layout (main.py at repo root)
WORKING_DIR = os.path.dirname(_self_dir) if os.path.basename(_self_dir) == "lib" else _self_dir
# Code lives in _self_dir (lib/ when installed, root in dev); config lives at WORKING_DIR root
STAGE_SCRIPT = os.path.join(_self_dir, "core", "stage.py")
PUBLISH_PIPELINE = os.path.join(_self_dir, "scripts", "publish_pipeline.sh")
BUILDERS_DIR = os.path.join(_self_dir, "builders")
ENV_FILE = os.path.join(WORKING_DIR, "data", "config.env")

# Allow importing core helpers
sys.path.append(_self_dir)
from core.keygen import update_config_env  # noqa: E402
from core.index import (  # noqa: E402
    add_version,
    create_index_mdata,
    create_pkg_md,
    edit_target,
    get_version,
    package_name,
    remove_version,
    safe_write_json,
)

load_dotenv(ENV_FILE)

# Always pin WORKING_DIR to the auto-detected install root.
# config.env may contain a stale hardcoded path; we must not let it win.
os.environ["WORKING_DIR"] = WORKING_DIR

_index_dir = os.getenv("INDEX_DIR", "metadata")
_index_file = os.getenv("INDEX_FILE", "index.json")
INDEX_PATH = os.path.join(WORKING_DIR, _index_dir, _index_file)

# Key storage defaults to $WORKING_DIR/keys so dev and installed layouts are
# each self-contained (no collision with an existing system-wide key).
DEFAULT_KEY_DIR = os.path.join(WORKING_DIR, "keys")

ALL_LINUX_BUILDERS = [
    "ubuntu_amd64",
    "arch_amd64",
    "debian_amd64",
    "alpine_amd64",
    # "ubuntu_arm64",
]


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


def _resolve_builders(spec: str) -> list:
    """Resolve a builder spec to a list of builder names."""
    if spec == "all":
        result = []
        for entry in sorted(os.listdir(BUILDERS_DIR)):
            if entry.endswith("-builder.yml"):
                result.append(entry[: -len("-builder.yml")])
        return result
    if spec == "all-linux":
        return list(ALL_LINUX_BUILDERS)
    # Check named group from env: BUILDER_GROUP_<NAME>
    env_key = f"BUILDER_GROUP_{spec.upper().replace('-', '_')}"
    group = os.getenv(env_key)
    if group:
        return [b.strip() for b in group.split(",") if b.strip()]
    return [spec]


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


def _parse_builder(builder: str) -> tuple:
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


def cmd_list(args: argparse.Namespace) -> int:
    md = _load_index(args.index)
    if not md:
        print("Index is empty.")
        return 0
    for pkg_name in sorted(md.keys()):
        pkg = md[pkg_name]
        latest = pkg.get("latest", "?")
        versions = pkg.get("versions", {})
        print(f"{pkg_name}  (latest: {latest})")
        for ver in sorted(versions.keys(), key=lambda v: list(map(int, v.split(".")))):
            targets = versions[ver].get("targets", {})
            target_list = ", ".join(sorted(targets.keys()))
            marker = " *" if ver == latest else ""
            print(f"  {ver}{marker}  [{target_list}]")
    return 0


def cmd_remove_version(args: argparse.Namespace) -> int:
    md = _load_index(args.index)
    removed = remove_version(md, args.name, args.version)
    if not removed:
        raise SystemExit(f"Version {args.version} of '{args.name}' not found in index.")
    _write_index(md, args.index)
    print(f"Removed {args.name} {args.version} from index.")
    if args.delete_release:
        if not shutil.which("gh"):
            print("Warning: 'gh' not found, skipping GitHub release deletion.")
        else:
            tag = f"{args.name}-v{args.version}"
            result = run(["gh", "release", "delete", tag, "--yes"], check=False)
            if result.returncode == 0:
                print(f"GitHub release {tag} deleted.")
            else:
                print(f"Warning: failed to delete GitHub release {tag}.")
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
    if args.explicit_version:
        cmd += ["--version", args.explicit_version]
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

    builders = _resolve_builders(
        args.builder or os.getenv("DEFAULT_BUILDER", "ubuntu_amd64")
    )

    env = os.environ.copy()
    env["PYTHONUNBUFFERED"] = "1"
    if args.explicit_version:
        env["EXPLICIT_VERSION"] = args.explicit_version
    if args.dry_run:
        env["DRY_RUN"] = "1"

    if shutil.which("stdbuf"):
        base_cmd = ["stdbuf", "-oL", "-eL", "bash", PUBLISH_PIPELINE]
    else:
        base_cmd = ["bash", PUBLISH_PIPELINE]

    if len(builders) == 1:
        # Single builder: pass as positional arg (backward compatible)
        cmd = base_cmd + [args.project_path, args.update_type, builders[0]]
        if args.stage_dir:
            cmd.append(args.stage_dir)
    else:
        # Multi-builder: pass BUILDERS env var, pipeline loops internally
        env["BUILDERS"] = " ".join(builders)
        cmd = base_cmd + [args.project_path, args.update_type]
        if args.stage_dir:
            cmd.append(args.stage_dir)

    try:
        run(cmd, check=True, env=env)
        return 0
    except CalledProcessError as exc:
        print(f"pipeline failed: {exc}")
        return exc.returncode or 1


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


def _get_builder_image(builder_name: str):
    """Read the 'image:' field from a builder YAML. Returns None if not found."""
    yml = os.path.join(BUILDERS_DIR, f"{builder_name}-builder.yml")
    if not os.path.exists(yml):
        return None
    with open(yml) as f:
        for line in f:
            stripped = line.strip()
            if stripped.startswith("image:"):
                return stripped.split(":", 1)[1].strip()
    return None


def cmd_keygen(args: argparse.Namespace) -> int:
    key_dir = os.path.expanduser(args.key_dir)
    priv_path = os.path.join(key_dir, "ci.key")
    pub_path = os.path.join(key_dir, "ci.pub")

    if (os.path.exists(priv_path) or os.path.exists(pub_path)) and not args.force:
        print("[keygen] Key(s) already exist:")
        if os.path.exists(priv_path):
            print(f"  private: {priv_path}")
        if os.path.exists(pub_path):
            print(f"  public:  {pub_path}")
        print("[keygen] Use --force to overwrite.")
        return 1

    os.makedirs(key_dir, exist_ok=True)
    print(f"[keygen] Generating minisign keypair in {key_dir}/")
    print("[keygen] You will be prompted to set a passphrase.\n")

    minisign_cmd = ["minisign", "-G", "-p", pub_path, "-s", priv_path]
    if args.force:
        # minisign refuses to overwrite without its own -f flag, so our
        # --force must propagate to the underlying tool.
        minisign_cmd.insert(2, "-f")
    result = run(minisign_cmd)
    if result.returncode != 0:
        print("[keygen] minisign key generation failed.", file=sys.stderr)
        return result.returncode

    if not os.path.exists(priv_path) or not os.path.exists(pub_path):
        print("[keygen] Key files not created (aborted?).", file=sys.stderr)
        return 1

    print(f"\n[keygen] Private key: {priv_path}")
    print(f"[keygen] Public key:  {pub_path}")

    if args.no_config:
        return 0

    answer = input("\n[keygen] Update config.env with these key paths and passphrase? [y/N] ").strip().lower()
    if answer != "y":
        print("[keygen] config.env not modified.")
        return 0

    sig_pass = getpass.getpass("[keygen] Enter the passphrase you just set: ")
    update_config_env(ENV_FILE, {
        "CI_KEY": priv_path,
        "PUB_KEY1": pub_path,
        "SIG_PASS": sig_pass,
    })
    print(f"[keygen] Updated {ENV_FILE}")
    return 0


def cmd_doctor(args: argparse.Namespace) -> int:
    # Each check: (label, passed, message, critical)
    results = []

    def _chk(label, passed, msg, critical=True):
        results.append((label, passed, msg, critical))

    # 1. External tools
    for tool in ["docker", "gh", "minisign", "jq", "sha256sum", "rsync"]:
        found = shutil.which(tool) is not None
        _chk(f"tool:{tool}", found, shutil.which(tool) or "NOT FOUND")

    # 2. config.env exists
    _chk("config.env", os.path.exists(ENV_FILE), ENV_FILE)

    # 3. Required env vars
    required = [
        "WORKING_DIR", "DEFAULT_BUILDER", "DEFAULT_STAGE", "GITHUB_REPO",
        "SIG_PASS", "CI_KEY", "INDEX_DIR", "INDEX_FILE", "PUB_KEY1",
    ]
    for var in required:
        val = os.getenv(var, "")
        _chk(f"env:{var}", bool(val), "<set>" if val else "<MISSING>")

    # 4. CI_KEY readable
    ci_key = os.getenv("CI_KEY", "")
    if ci_key:
        ok = os.path.isfile(ci_key) and os.access(ci_key, os.R_OK)
        _chk("CI_KEY readable", ok, ci_key if ok else f"{ci_key} (not found or not readable)")

    # 5. PUB_KEY1 exists
    pub_key = os.getenv("PUB_KEY1", "")
    if pub_key:
        if not os.path.isabs(pub_key):
            pub_key = os.path.join(WORKING_DIR, pub_key)
        _chk("PUB_KEY1 exists", os.path.isfile(pub_key), pub_key)

    # 6. DEFAULT_STAGE directory exists (non-critical)
    stage = os.getenv("DEFAULT_STAGE", "")
    if stage:
        _chk("DEFAULT_STAGE", os.path.isdir(stage), stage, critical=False)

    # 7. gh auth
    if shutil.which("gh"):
        result = run(["gh", "auth", "status"], capture_output=True)
        _chk("gh auth", result.returncode == 0,
             "authenticated" if result.returncode == 0 else "NOT authenticated (run: gh auth login)")
    else:
        _chk("gh auth", False, "gh not on PATH — skipped")

    # 8. Docker daemon
    if shutil.which("docker"):
        result = run(["docker", "info"], capture_output=True)
        _chk("docker daemon", result.returncode == 0,
             "running" if result.returncode == 0 else "NOT running")
    else:
        _chk("docker daemon", False, "docker not on PATH — skipped")

    # 8b. Docker compose v2 (the pipeline uses `docker compose`, not `docker-compose`)
    if shutil.which("docker"):
        result = run(["docker", "compose", "version"], capture_output=True)
        _chk("docker compose", result.returncode == 0,
             "available" if result.returncode == 0 else "NOT available (install docker compose v2)")
    else:
        _chk("docker compose", False, "docker not on PATH — skipped")

    # 9. Builder images
    builder_spec = args.builder or os.getenv("DEFAULT_BUILDER", "ubuntu_amd64")
    for builder in _resolve_builders(builder_spec):
        image = _get_builder_image(builder)
        if image is None:
            _chk(f"image:{builder}", False, f"builder YAML not found for '{builder}'")
            continue
        if not shutil.which("docker"):
            _chk(f"image:{builder}", False, "docker not on PATH — skipped")
            continue
        result = run(["docker", "image", "inspect", image], capture_output=True)
        ok = result.returncode == 0
        _chk(f"image:{builder}", ok,
             f"'{image}' exists" if ok else f"'{image}' not found (run: scripts/build_images.sh {builder})")

    # --- Print results ---
    label_width = max(len(r[0]) for r in results)
    any_critical_fail = False
    for label, passed, msg, critical in results:
        if passed:
            status = "PASS"
        elif not critical:
            status = "WARN"
        else:
            status = "FAIL"
            any_critical_fail = True
        print(f"  [{status:<4}] {label:<{label_width}}  {msg}")

    print()
    if any_critical_fail:
        print("doctor: one or more critical checks failed.")
        return 1
    print("doctor: all critical checks passed.")
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Repman CI Runner")
    sub = p.add_subparsers(dest="cmd", required=True)

    # Shared parent parser for run/update (avoids duplicating argument definitions)
    _run_parent = argparse.ArgumentParser(add_help=False)
    _run_parent.add_argument("project_path", help="Path to the project to build and publish")
    _run_parent.add_argument(
        "update_type",
        choices=["major", "minor", "patch", "new"],
        help="Version update type",
    )
    _run_parent.add_argument("-b", "--builder", help="Builder or group (e.g. ubuntu_amd64, all-linux, all)")
    _run_parent.add_argument("--stage-dir", help="Staging/output directory override")
    _run_parent.add_argument(
        "--version",
        dest="explicit_version",
        default=None,
        metavar="X.Y.Z",
        help="Explicit version override. Skips automatic version bump.",
    )
    _run_parent.add_argument(
        "--dry-run",
        action="store_true",
        default=False,
        help="Print what would happen without executing builds or publishing.",
    )

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

    # list
    sp = sub.add_parser("list", help="List all packages, versions, and targets")
    sp.add_argument("--index", default=INDEX_PATH, help="Path to index.json (default: %(default)s)")
    sp.set_defaults(func=cmd_list)

    # stage
    sp = sub.add_parser("stage", help="Stage a program version (metadata + pkg md)")
    sp.add_argument("name", help="Program name to stage")
    sp.add_argument("update_type", choices=["major", "minor", "patch", "new"], help="Version update type")
    sp.add_argument("-b", "--builder", help="Builder to use (e.g. ubuntu_amd64)")
    sp.add_argument("-e", "--env", help="Path to env file to load")
    sp.add_argument("--metadata-file", help="Path to index.json (override)")
    sp.add_argument("--out-dir", help="Output directory for package metadata")
    sp.add_argument(
        "--version",
        dest="explicit_version",
        default=None,
        metavar="X.Y.Z",
        help="Explicit version override. Skips automatic version bump.",
    )
    sp.set_defaults(func=cmd_stage)

    # run (pipeline)
    sp = sub.add_parser("run", parents=[_run_parent], help="Run full publish pipeline for a project")
    sp.set_defaults(func=cmd_run)

    # update (alias of run — shares same parser and function)
    sp = sub.add_parser("update", parents=[_run_parent], help="Alias of 'run'")
    sp.set_defaults(func=cmd_run)

    # remove-version
    sp = sub.add_parser("remove-version", help="Remove a version entry from the index")
    sp.add_argument("--index", default=INDEX_PATH, help="Path to index.json (default: %(default)s)")
    sp.add_argument("name", help="Package name")
    sp.add_argument("version", help="Version to remove (e.g. 1.2.3)")
    sp.add_argument(
        "--delete-release",
        action="store_true",
        help="Also delete the corresponding GitHub release via gh",
    )
    sp.set_defaults(func=cmd_remove_version)

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

    # keygen
    sp = sub.add_parser("keygen", help="Generate a minisign keypair for signing")
    sp.add_argument(
        "--key-dir",
        default=DEFAULT_KEY_DIR,
        help=f"Directory to store keys (default: {DEFAULT_KEY_DIR})",
    )
    sp.add_argument("-f", "--force", action="store_true", help="Overwrite existing keys without prompting")
    sp.add_argument("--no-config", action="store_true", help="Skip the offer to update config.env")
    sp.set_defaults(func=cmd_keygen)

    # doctor
    sp = sub.add_parser("doctor", help="Run pre-flight health checks")
    sp.add_argument(
        "--builder",
        default=None,
        help="Builder(s) to check images for (default: DEFAULT_BUILDER from config)",
    )
    sp.set_defaults(func=cmd_doctor)

    return p


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    rc = args.func(args)  # type: ignore[attr-defined]
    raise SystemExit(rc)


if __name__ == "__main__":
    main()
