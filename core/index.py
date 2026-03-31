from json import dump
from os import fdopen, fsync, makedirs, path, remove, replace
from tempfile import mkstemp

PACKAGE_DIR = "https://example.com/package"


# Index helpers for package metadata management

def create_index_mdata(metadata, name, version, os, arch, url=PACKAGE_DIR) -> dict:
    """Initialize index metadata entry for a package.

    Args:
        metadata: The global metadata dict to mutate.
        name: Package name.
        version: Semver string (e.g., 1.2.3).
        os: Target operating system (e.g., linux, macos).
        arch: Target architecture (e.g., amd64, arm64).
    Returns:
        The mutated metadata dict.
    """
    metadata[name] = {
        "latest": version,
        "versions": {
            f"{version}": {
                "targets": {
                    f"{os}_{arch}": {
                        "url": f"{url}",
                        "signature": f"{package_name(name, version, os, arch, 1)}",
                        "sha256" : f"{package_name(name, version, os, arch, 2)}"
                    }
                }
            }
        },
    }
    return metadata

def edit_target(metadata, name, version, os, arch, key, value) -> bool:
    """Edit a target for a given os/arch version."""
    if metadata.get(name) is None or metadata[name]["versions"].get(version) is None: return False
    target = metadata[name]["versions"][version]["targets"].get(f"{os}_{arch}")
    if target is None: return False
    if key not in target: return False

    target[key] = value
    return True

def greater_version(v1: str, v2: str) -> bool:
    """Return True if v1 is strictly greater than v2. If v2 is None, True."""
    if v2 is None:
        return True
    v1_major, v1_minor, v1_patch = map(int, v1.split("."))
    v2_major, v2_minor, v2_patch = map(int, v2.split("."))
    if v1_major > v2_major:
        return True
    if v1_major == v2_major and v1_minor > v2_minor:
        return True
    if v1_major == v2_major and v1_minor == v2_minor and v1_patch > v2_patch:
        return True
    return False


def add_version(metadata, name, version, os, arch, url=PACKAGE_DIR):
    """Add a version for a given os/arch target, updating latest if needed."""
    if metadata.get(name) is None:
        create_index_mdata(metadata, name, version, os, arch, url)
        return metadata

    if greater_version(version, metadata[name]["latest"]):
        metadata[name]["latest"] = version
    if metadata[name]["versions"].get(version) is None:
        metadata[name]["versions"][version] = {
            "targets": {
                f"{os}_{arch}": {
                    "url": f"{url}",
                    "signature": f"{package_name(name, version, os, arch, 1)}",
                    "sha256" : f"{package_name(name, version, os, arch, 2)}"
                }
            }
        }
    else:
        if (
            metadata[name]["versions"][version]
            .get("targets")
            .get(f"{os}_{arch}")
            is None
        ):
            metadata[name]["versions"][version]["targets"][f"{os}_{arch}"] = {
                "url": f"{url}",
                "signature": f"{package_name(name, version, os, arch, 1)}",
                "sha256" : f"{package_name(name, version, os, arch, 2)}"
            }
        else:
            print(f"Version {version} already exists for program {name}.")
            return metadata
    return metadata


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

def create_pkg_md(name: str, version: str, os: str, arch: str, dep: dict=None) -> dict:
    """Create a package metadata document for a single build artifact."""
    if dep is None:
        dep = {}
    metadata = {
        "name": name,
        "version": version,
        "os": os,
        "arch": arch,
        "dependencies": dep,
    }
    return metadata


# Fix me: not sure if hardcoding .tar.gz.minisig here is a good idea.
def package_name(name: str, version: str="", os: str="", arch: str="", sig: int=0) -> str:
    """Create a package name from the package name and metadata."""

    if sig == 1:
        return f"{name}_v{version}_{os}_{arch}.tar.gz.minisig".lower()
    elif sig == 2:
        return f"{name}_v{version}_{os}_{arch}.tar.gz.sha256".lower()
    else:
        return f"{name}_v{version}_{os}_{arch}".lower()


def get_version(md, name, os, arch) -> str:
    # get latest version of type os_arch
    if md.get(name) is None:
        return None
    latest_version = None

    for ver in md[name]["versions"].keys():
        for os_arch in md[name]["versions"][ver]["targets"].keys():
            if (os_arch == f"{os}_{arch}" and greater_version(ver, latest_version)):
                latest_version = ver

    return latest_version

def remove_version(metadata: dict, name: str, version: str) -> bool:
    """Remove a version entry from the index.

    If removing the current latest, promotes the next highest remaining version.
    If no versions remain, removes the package entry entirely.
    Returns True if the version was found and removed, False otherwise.
    """
    if name not in metadata:
        return False
    versions = metadata[name].get("versions", {})
    if version not in versions:
        return False
    del versions[version]
    if metadata[name].get("latest") == version:
        remaining = sorted(
            versions.keys(),
            key=lambda v: list(map(int, v.split("."))),
        )
        if remaining:
            metadata[name]["latest"] = remaining[-1]
        else:
            del metadata[name]
    return True


def safe_write_json(file_path: str, data) -> None:
    directory = path.dirname(file_path) or "."
    makedirs(directory, exist_ok=True)
    fd, tmp_path = mkstemp(prefix=".tmp_", dir=directory)
    try:
        with fdopen(fd, "w") as tmp_file:
            dump(data, tmp_file, indent=4)
            tmp_file.flush()
            fsync(tmp_file.fileno())
        replace(tmp_path, file_path)
    finally:
        if path.exists(tmp_path):
            try:
                remove(tmp_path)
            except OSError:
                pass
