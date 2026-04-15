"""keygen.py — config.env update helper for repcid keygen."""

import os
import re
import tempfile

_KEY_PATTERN = re.compile(r'^(export\s+)?(\w+)=')


def update_config_env(config_path: str, updates: dict) -> None:
    """Update specific key=value pairs in a shell config.env file.

    Preserves all comments, ordering, and existing 'export' prefixes.
    Keys not found are appended at the end. Writes atomically via
    tempfile + os.replace() so a crash mid-write cannot corrupt the file.

    Args:
        config_path: Absolute path to the config.env file.
        updates: Dict of {KEY: value} to set (values are written unquoted).
    """
    if not os.path.exists(config_path):
        example = config_path + ".example"
        if os.path.exists(example):
            import shutil
            shutil.copy(example, config_path)
        else:
            open(config_path, "w").close()

    with open(config_path, "r") as f:
        lines = f.readlines()

    found = set()
    out_lines = []
    for line in lines:
        m = _KEY_PATTERN.match(line)
        if m and m.group(2) in updates:
            prefix = m.group(1) or ""
            out_lines.append(f"{prefix}{m.group(2)}={updates[m.group(2)]}\n")
            found.add(m.group(2))
        else:
            out_lines.append(line)

    for key, val in updates.items():
        if key not in found:
            out_lines.append(f"{key}={val}\n")

    dir_ = os.path.dirname(os.path.abspath(config_path))
    fd, tmp = tempfile.mkstemp(dir=dir_)
    try:
        with os.fdopen(fd, "w") as f:
            f.writelines(out_lines)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, config_path)
    except Exception:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise
