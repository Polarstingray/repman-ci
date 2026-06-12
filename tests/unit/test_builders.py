"""Unit tests for the shared core/builders.parse_builder helper."""
import os
import sys

import pytest

REPO_ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
sys.path.insert(0, REPO_ROOT)

from core.builders import parse_builder  # noqa: E402


class TestParseBuilder:
    def test_valid_builder_splits_into_os_arch(self):
        assert parse_builder("ubuntu_amd64") == ("ubuntu", "amd64")

    @pytest.mark.parametrize(
        "bad",
        [
            "ubuntu_22_amd64",  # too many underscores
            "ubuntu",           # no underscore
            "",                 # empty string
            "_amd64",           # empty os
            "ubuntu_",          # empty arch
            "_",                # both empty
        ],
    )
    def test_malformed_builder_raises_value_error(self, bad):
        with pytest.raises(ValueError):
            parse_builder(bad)

    def test_error_message_is_clear(self):
        with pytest.raises(ValueError) as exc_info:
            parse_builder("ubuntu_22_amd64")
        msg = str(exc_info.value)
        assert "<os>_<arch>" in msg
        assert "ubuntu_22_amd64" in msg
