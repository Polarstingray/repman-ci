"""Shared parsing for '<os>_<arch>' builder strings.

A builder names a target as '<os>_<arch>', e.g. 'ubuntu_amd64'. This module
is the single source of truth for splitting and validating that form so that
the CLI (main.py) and the staging logic (core/stage.py) report the same clear
error instead of diverging or surfacing an opaque unpack error.
"""

BUILDER_FORM = "<os>_<arch>"
BUILDER_EXAMPLE = "ubuntu_amd64"


def parse_builder(builder: str) -> tuple:
    """Split a builder string into (os, arch).

    The builder must be exactly two non-empty parts joined by a single
    underscore, e.g. 'ubuntu_amd64'. Anything else (too many underscores,
    no underscore, or empty parts) raises a ValueError with a clear message.
    """
    parts = builder.split("_") if builder else []
    if len(parts) != 2 or not parts[0] or not parts[1]:
        raise ValueError(
            f"Invalid builder {builder!r}: must be in the form "
            f"'{BUILDER_FORM}' e.g., '{BUILDER_EXAMPLE}'"
        )
    return parts[0], parts[1]
