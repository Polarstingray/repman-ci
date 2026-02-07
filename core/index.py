
PACKAGE_DIR = "https://example.com/package"  

def create_index_mdata(metadata, name, version, arch, os) -> dict:
    metadata[name] = {
        "latest": version,
        "versions" : { 
            f"{version}" : {
                "targets" :  {
                    f"{os}_{arch}": {
                        "url" : f"{PACKAGE_DIR}",
                        "signature" : ""
                    }
                }
            }
        }
    }
    return metadata


def is_latest(metadata, name, version) -> bool:
    lmajor, lminor, lpatch = map(int, metadata[name]["latest"].split("."))
    rmajor, rminor, rpatch = map(int, version.split("."))  
    return lmajor < rmajor or (lmajor == rmajor and lminor < rminor) or (lmajor == rmajor and lminor == rminor and lpatch < rpatch)


def add_version(metadata, name, version, arch, os) :
    if metadata.get(name) is None : 
        create_index_mdata(metadata, name, version, arch, os)
        return metadata
    

    if is_latest(metadata, name, version) :
        metadata[name]["latest"] = version
    if metadata[name]["versions"].get(version) is None :
        metadata[name]["versions"][version] = {
            "targets" :  {
                f"{os}_{arch}": {
                    "url" : f"{PACKAGE_DIR}",
                    "signature" : ""
                }
            }
        }
    else:
        if metadata[name]["versions"][version].get("targets").get(f"{os}_{arch}") is None :
            metadata[name]["versions"][version]["targets"][f"{os}_{arch}"] = {
                "url" : f"{PACKAGE_DIR}",
                "signature" : ""
            }
        else:
            print(f"Version {version} already exists for program {name}.")
            return metadata
    return metadata


def create_pkg_md(name, version, os, arch, dep={}) -> dict:
    metadata = {
        "name": name,
        "version": version,
        "os": os,
        "arch": arch,
        "dependencies" : dep
    }
    return metadata

def package_name(name: str, md: dict) -> str:
    return f"{name}_v{md.get('version')}_{md.get('os')}_{md.get('arch')}".lower()

def greater_version(v1, v2) -> bool:
    v1_major, v1_minor, v1_patch = map(int, v1.split("."))
    v2_major, v2_minor, v2_patch = map(int, v2.split("."))
    if v1_major > v2_major : return True
    elif v1_major == v2_major and v1_minor > v2_minor : return True
    elif v1_major == v2_major and v1_minor == v2_minor and v1_patch > v2_patch : return True

def get_version(md, name, arch, os) -> str:
    # get latest version of type os_arch

    if md.get(name) is None : return None
    latest_version = None

    for ver in md[name]['versions'].keys() :
        for os_arch in md[name]['versions'][ver]["targets"].keys():
            if (os_arch == f"{os}_{arch}" and latest_version is None) or (os_arch == f"{os}_{arch}" and greater_version(ver,latest_version)) :
                latest_version = ver

    return latest_version
   

def main() :
    metadata = {}

    create_index_mdata(metadata, "example_program", "1.0.0", "linux", "amd64")
    add_version(metadata, "example_program", "1.0.1", "linux", "amd64")
    add_version(metadata, "example_program", "1.0.2", "linux", "amd64")

    create_index_mdata(metadata, "example_program2", "1.1.0", "linux", "amd64")
    add_version(metadata, "example_program2", "1.1.1", "linux", "amd64")
    add_version(metadata, "example_program2", "1.1.2", "linux", "amd64")
    add_version(metadata, "example_program2", "1.1.2", "macos", "arm64")

    #test
    version = get_version(metadata, "example_program", "linux", "amd64")
    print(f"Latest Version of linux amd64: {version}")

    add_version(metadata, "example_program", "1.0.3", "linux", "amd64")
    add_version(metadata, "example_program", "1.0.4", "arch", "amd64")

    version = get_version(metadata, "example_program", "linux", "amd64")
    print(f"Latest Version of linux amd64: {version}")

    # print(metadata)

    for name, md in metadata.items():
        print(f"Package: {name}")
        print(f"Latest Version: {md['latest']}")
        # print(f"Versions: {md['versions']}")
        for version, targets in md['versions'].items():
            print(f"v{version} : {targets}")
        print()

    print(metadata)


    pass


if __name__ == "__main__" :
    main()

