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
                        "signature": "",
                    }
                }
            }
        },
    }
    return metadata


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
                    "signature": "",
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
                "signature": "",
            }
        else:
            print(f"Version {version} already exists for program {name}.")
            return metadata
    return metadata


def create_pkg_md(name, version, os, arch, dep=None) -> dict:
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


def package_name(name: str, md: dict) -> str:
    return f"{name}_v{md.get('version')}_{md.get('os')}_{md.get('arch')}".lower()


def greater_version(v1, v2) -> bool:
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
            if (
                os_arch == f"{os}_{arch}" and greater_version(ver, latest_version)
            ):
                latest_version = ver

    return latest_version


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
