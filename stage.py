
#/!/bin/python3


import os
import sys
import json
import argparse

parser = argparse.ArgumentParser(description="CI Runner")
parser.add_argument("name", type=str, help="Name of program being staged.")
parser.add_argument("update_type", type=str, help="Type of update to apply to the version.")
parser.add_argument("-e", "--env", type=str, help="Path to environment file") 

args = parser.parse_args()
WORKING_DIR = os.path.dirname(os.path.abspath(__file__))

def update_version(version, update_type) :
    tmp = version.split(".")
    major = tmp[0]
    minor = tmp[1]
    patch = tmp[2]  
    if update_type == "major" :
        major = int(major) + 1
        minor = 0
        patch = 0
    elif update_type == "minor" :
        minor = int(minor) + 1
        patch = 0
    elif update_type == "patch" :
        patch = int(patch) + 1
    else :
        raise ValueError("Invalid update type")
    return f"{major}.{minor}.{patch}"


def package_name(name, md) :
    return f"{name}_{md.get("version")}_{md.get("os")}_{md.get("arch")}".lower()

def main() :
    with open(f"{WORKING_DIR}/metadata/stage.json", "r") as f:
        metadata = json.load(f)
        print(metadata)

    if args.name not in metadata:
        metadata[args.name] = {
            "name" : args.name,
            "version": "1.0.0",
            "os": "Ubuntu22",
            "arch" : "x86_64",
            "dependencies": {}
        }
    else :
        curr_version = metadata[args.name].get("version", "1.0.0")
        version = update_version(curr_version, args.update_type)
        metadata[args.name]["version"] = version
        metadata[args.name]["arch"] = "x86-64"

    with open(f"{WORKING_DIR}/metadata/stage.json", "w") as f:
        json.dump(metadata, f, indent=4)
    print(f"Program {args.name} has been staged.")

    pkg_name = package_name(args.name, metadata[args.name])
    with open(f"{WORKING_DIR}/out/{pkg_name}_md.json", "w") as f:
        metadata[args.name] = json.dump(metadata[args.name], f, indent=4)

    print("Package name: ")
    print(pkg_name)

if __name__ == "__main__":
    main()




