import argparse
from ci_runner.stage import ensure_environment, safe_write_json, index_mdata
# from ci_runner.config import config


def shell(cmd: str, args: list[str]=[]) -> str :
    match cmd :
        case "update" :
            return "Updating..."
        case "get_version" :
            return
        case "get_index" :
            return
        case "get_builders" :
            return
        case "get_env" :
            return
    pass


def main() -> None :
    pass


if __name__ == "__main__" :
    main()








