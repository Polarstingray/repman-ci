
#!/bin/python3


import os
import sys
import json
import argparse

parser = argparse.ArgumentParser(description="CI Runner")
parser.add_argument("name", type=str, help="Name of program being staged.")
parser.add_argument("update_type", type=str, help="Type of update to apply to the version.")
parser.add_argument("-e", "--env", type=str, help="Path to environment file") 

args = parser.parse_args()

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


def main() :
    with open("metadata/stage.json", "r") as f:
        metadata = json.load(f)
        print(metadata)

    if args.name not in metadata:
        metadata[args.name] = {
            "version": "1.0.0",
            "os": "Linux",
            "dependencies": {}
        }
        # metadata[args.name]["version"] =  "1.0.0"
        # metadata[args.name]["os"] = "Linux"
        # metadata[args.name]["dependencies"] = {}
        with open("metadata/stage.json", "w") as f:
            json.dump(metadata, f, indent=4)
        print(f"Program {args.name} has been staged.")
    else :
        curr_version = metadata[args.name].get("version", "1.0.0")
        version = update_version(curr_version, args.update_type)
        metadata[args.name]["version"] = version
        print(metadata)


if __name__ == "__main__":
    main()




