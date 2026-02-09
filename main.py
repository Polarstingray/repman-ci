#!/usr/bin/env python3

import argparse
from subprocess import run, check_output

from os import path
from dotenv import load_dotenv
import sys

WORKING_DIR = path.dirname(path.dirname(path.abspath(__file__)))
INDEX = path.join(WORKING_DIR, "metadata", "index.json")
sys.path.append(WORKING_DIR)
from core.index import * 

ENV_FILE = path.join(WORKING_DIR, ".env")
load_dotenv(ENV_FILE)


def shell(cmd: str, args: list[str]=[]) -> str :
    match cmd :
        case "add_sha256" :
            return ""
        case "update" :
            return "Updating..."
        case "get_version" :
            return "version"
        case "get_index" :
            return
        case "get_builders" :
            return
        case "get_env" :
            return
        case "stage" :
            run(["./stage"] + args, check=True)
            return 
        case "update_builders" :
            return
        case "get_builders" :
            pass
        case "config" :
            run(["nano", ".env"])
            pass
        case "run" :
            pass
    pass


def main() -> None :
    parser = argparse.ArgumentParser(description="CI Runner")
    parser.add_argument("command", choices=["update", "get_version", "get_index", "get_builders", "get_env", "stage", "update_builders", "get_builders", "config", "run"], help="Command to run")
    args, uknown_args = parser.parse_known_args()

    print(shell(args.command, uknown_args))
    pass


if __name__ == "__main__" :
    main()








