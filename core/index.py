from json import dump
from os import fdopen, fsync, makedirs, path, remove, replace
from tempfile import mkstemp

PACKAGE_DIR = "https://example.com/package"


# Index helpers for package metadata management

def create_index_mdata(metadata, name, version, os, arch) -> dict:
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
                        "url": f"{PACKAGE_DIR}",
                        "signature": f"{package_name(name, None, version, os, arch, True)}",
                        "sha256" : ""
                    }
                }
            }
        },
    }
    return metadata

def edit_target(metadata, name, version, os, arch, key, value) -> bool:
    """Edit a target for a given os/arch version."""
    if metadata.get(name) is None or metadata[name]["versions"].get(version) is None: return False
    if metadata[name]["versions"][version]["targets"].get(f"{os}_{arch}") is None : return False
    if not metadata[name]["versions"][version]["targets"].get(f"{os}_{arch}").get(key): return False

    metadata[name]["versions"][version]["targets"][f"{os}_{arch}"][key] = value
    return True



def is_latest(metadata, name, version) -> bool:
    """Return True if provided version is greater than current latest."""
    lmajor, lminor, lpatch = map(int, metadata[name]["latest"].split("."))
    rmajor, rminor, rpatch = map(int, version.split("."))
    return (
        lmajor < rmajor
        or (lmajor == rmajor and lminor < rminor)
        or (lmajor == rmajor and lminor == rminor and lpatch < rpatch)
    )


def add_version(metadata, name, version, os, arch):
    """Add a version for a given os/arch target, updating latest if needed."""
    if metadata.get(name) is None:
        create_index_mdata(metadata, name, version, os, arch)
        return metadata

    if is_latest(metadata, name, version):
        metadata[name]["latest"] = version
    if metadata[name]["versions"].get(version) is None:
        metadata[name]["versions"][version] = {
            "targets": {
                f"{os}_{arch}": {
                    "url": f"{PACKAGE_DIR}",
                    "signature": f"{package_name(name, None, version, os, arch, True)}",
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
                "url": f"{PACKAGE_DIR}",
                "signature": f"{package_name(name, None, version, os, arch, True)}",
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
def package_name(name: str, md: dict=None, version: str="", os: str="", arch: str="", sig: bool=False) -> str:
    """Create a package name from the package name and metadata."""
    ext = ".tar.gz.minisig" if sig else ""
    if md is None:
        if version == "" or os == "" or arch == "": return None
        return f"{name}_v{version}_{os}_{arch}{ext}".lower()
    return f"{name}_v{md.get('version')}_{md.get('os')}_{md.get('arch')}{ext}".lower()


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


def main():
    metadata = {}

    create_index_mdata(metadata, "example_program", "1.0.0", "linux", "amd64")
    add_version(metadata, "example_program", "1.0.1", "linux", "amd64")
    add_version(metadata, "example_program", "1.0.2", "linux", "amd64")

    create_index_mdata(metadata, "example_program2", "1.1.0", "linux", "amd64")
    add_version(metadata, "example_program2", "1.1.1", "linux", "amd64")
    add_version(metadata, "example_program2", "1.1.2", "linux", "amd64")
    add_version(metadata, "example_program2", "1.1.2", "macos", "arm64")

    # test
    version = get_version(metadata, "example_program", "linux", "amd64")
    print(f"Latest Version of linux amd64: {version}")

    add_version(metadata, "example_program", "1.0.3", "linux", "amd64")
    add_version(metadata, "example_program", "1.0.4", "arch", "amd64")

    version = get_version(metadata, "example_program", "linux", "amd64")
    print(f"Latest Version of linux amd64: {version}")

    for name, md in metadata.items():
        print(f"Package: {name}")
        print(f"Latest Version: {md['latest']}")
        for version, targets in md["versions"].items():
            print(f"v{version} : {targets}")
        print()

    print(metadata)


if __name__ == "__main__":
    main()
