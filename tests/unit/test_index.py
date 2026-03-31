"""Unit tests for core/index.py"""
import json
import os
import sys
import tempfile

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))
from core.index import (
    add_version,
    create_index_mdata,
    create_pkg_md,
    edit_target,
    get_version,
    greater_version,
    package_name,
    remove_version,
    safe_write_json,
    update_version,
)


# ---------------------------------------------------------------------------
# create_index_mdata
# ---------------------------------------------------------------------------

class TestCreateIndexMdata:
    def test_creates_top_level_keys(self):
        md = {}
        create_index_mdata(md, "mypkg", "1.0.0", "ubuntu", "amd64")
        assert "mypkg" in md
        assert md["mypkg"]["latest"] == "1.0.0"
        assert "versions" in md["mypkg"]

    def test_creates_correct_target_key(self):
        md = {}
        create_index_mdata(md, "mypkg", "1.2.3", "debian", "arm64")
        targets = md["mypkg"]["versions"]["1.2.3"]["targets"]
        assert "debian_arm64" in targets

    def test_signature_and_sha256_fields(self):
        md = {}
        create_index_mdata(md, "mypkg", "1.0.0", "ubuntu", "amd64")
        target = md["mypkg"]["versions"]["1.0.0"]["targets"]["ubuntu_amd64"]
        assert target["signature"].endswith(".tar.gz.minisig")
        assert target["sha256"].endswith(".tar.gz.sha256")
        assert "url" in target

    def test_url_is_passed_through(self):
        md = {}
        create_index_mdata(md, "mypkg", "1.0.0", "ubuntu", "amd64", url="https://example.com/test")
        target = md["mypkg"]["versions"]["1.0.0"]["targets"]["ubuntu_amd64"]
        assert target["url"] == "https://example.com/test"


# ---------------------------------------------------------------------------
# edit_target
# ---------------------------------------------------------------------------

class TestEditTarget:
    def _base(self):
        md = {}
        create_index_mdata(md, "mypkg", "1.0.0", "ubuntu", "amd64")
        return md

    def test_missing_package_returns_false(self):
        assert edit_target({}, "missing", "1.0.0", "ubuntu", "amd64", "url", "x") is False

    def test_missing_version_returns_false(self):
        md = self._base()
        assert edit_target(md, "mypkg", "9.9.9", "ubuntu", "amd64", "url", "x") is False

    def test_missing_target_returns_false(self):
        md = self._base()
        assert edit_target(md, "mypkg", "1.0.0", "arch", "amd64", "url", "x") is False

    def test_missing_key_returns_false(self):
        md = self._base()
        assert edit_target(md, "mypkg", "1.0.0", "ubuntu", "amd64", "nonexistent_key", "x") is False

    def test_valid_edit_returns_true_and_updates(self):
        md = self._base()
        result = edit_target(md, "mypkg", "1.0.0", "ubuntu", "amd64", "url", "https://new.url")
        assert result is True
        assert md["mypkg"]["versions"]["1.0.0"]["targets"]["ubuntu_amd64"]["url"] == "https://new.url"


# ---------------------------------------------------------------------------
# greater_version
# ---------------------------------------------------------------------------

class TestGreaterVersion:
    def test_v2_none_returns_true(self):
        assert greater_version("1.0.0", None) is True

    def test_major_wins(self):
        assert greater_version("2.0.0", "1.9.9") is True

    def test_minor_wins(self):
        assert greater_version("1.2.0", "1.1.9") is True

    def test_patch_wins(self):
        assert greater_version("1.0.1", "1.0.0") is True

    def test_equal_is_false(self):
        assert greater_version("1.0.0", "1.0.0") is False

    def test_lower_is_false(self):
        assert greater_version("1.0.0", "1.0.1") is False

    def test_lower_major_is_false(self):
        assert greater_version("1.5.0", "2.0.0") is False


# ---------------------------------------------------------------------------
# add_version
# ---------------------------------------------------------------------------

class TestAddVersion:
    def test_new_package_creates_entry(self):
        md = {}
        add_version(md, "newpkg", "1.0.0", "ubuntu", "amd64")
        assert "newpkg" in md
        assert md["newpkg"]["latest"] == "1.0.0"

    def test_higher_version_updates_latest(self):
        md = {}
        add_version(md, "p", "1.0.0", "ubuntu", "amd64")
        add_version(md, "p", "1.1.0", "ubuntu", "amd64")
        assert md["p"]["latest"] == "1.1.0"

    def test_lower_version_keeps_latest(self):
        md = {}
        add_version(md, "p", "2.0.0", "ubuntu", "amd64")
        add_version(md, "p", "1.0.0", "ubuntu", "amd64")
        assert md["p"]["latest"] == "2.0.0"

    def test_duplicate_target_is_noop(self, capsys):
        md = {}
        add_version(md, "p", "1.0.0", "ubuntu", "amd64")
        add_version(md, "p", "1.0.0", "ubuntu", "amd64")
        captured = capsys.readouterr()
        assert "already exists" in captured.out
        # Only one target entry
        assert len(md["p"]["versions"]["1.0.0"]["targets"]) == 1

    def test_new_target_on_existing_version_is_added(self):
        md = {}
        add_version(md, "p", "1.0.0", "ubuntu", "amd64")
        add_version(md, "p", "1.0.0", "debian", "amd64")
        targets = md["p"]["versions"]["1.0.0"]["targets"]
        assert "ubuntu_amd64" in targets
        assert "debian_amd64" in targets


# ---------------------------------------------------------------------------
# update_version
# ---------------------------------------------------------------------------

class TestUpdateVersion:
    def test_major_bump(self):
        assert update_version("1.2.3", "major") == "2.0.0"

    def test_minor_bump(self):
        assert update_version("1.2.3", "minor") == "1.3.0"

    def test_patch_bump(self):
        assert update_version("1.2.3", "patch") == "1.2.4"

    def test_major_resets_minor_and_patch(self):
        result = update_version("3.7.12", "major")
        assert result == "4.0.0"

    def test_minor_resets_patch(self):
        result = update_version("1.2.9", "minor")
        assert result == "1.3.0"

    def test_invalid_type_raises(self):
        with pytest.raises(ValueError):
            update_version("1.0.0", "new")

    def test_invalid_format_raises(self):
        with pytest.raises(ValueError):
            update_version("1.0", "patch")


# ---------------------------------------------------------------------------
# create_pkg_md
# ---------------------------------------------------------------------------

class TestCreatePkgMd:
    def test_all_fields_present(self):
        md = create_pkg_md("mypkg", "1.0.0", "ubuntu", "amd64")
        assert md["name"] == "mypkg"
        assert md["version"] == "1.0.0"
        assert md["os"] == "ubuntu"
        assert md["arch"] == "amd64"
        assert "dependencies" in md

    def test_default_dependencies_empty(self):
        md = create_pkg_md("mypkg", "1.0.0", "ubuntu", "amd64")
        assert md["dependencies"] == {}

    def test_custom_dependencies(self):
        deps = {"libfoo": "1.2"}
        md = create_pkg_md("mypkg", "1.0.0", "ubuntu", "amd64", dep=deps)
        assert md["dependencies"] == deps


# ---------------------------------------------------------------------------
# package_name
# ---------------------------------------------------------------------------

class TestPackageName:
    def test_sig0_no_extension(self):
        result = package_name("mypkg", "1.0.0", "ubuntu", "amd64", 0)
        assert result == "mypkg_v1.0.0_ubuntu_amd64"

    def test_sig1_minisig_extension(self):
        result = package_name("mypkg", "1.0.0", "ubuntu", "amd64", 1)
        assert result == "mypkg_v1.0.0_ubuntu_amd64.tar.gz.minisig"

    def test_sig2_sha256_extension(self):
        result = package_name("mypkg", "1.0.0", "ubuntu", "amd64", 2)
        assert result == "mypkg_v1.0.0_ubuntu_amd64.tar.gz.sha256"

    def test_output_is_lowercase(self):
        result = package_name("MyPkg", "1.0.0", "Ubuntu", "AMD64", 0)
        assert result == result.lower()

    def test_name_only_with_defaults(self):
        # Calling with only name and defaults produces _v__ suffixes (empty fields)
        result = package_name("mypkg")
        assert result == "mypkg_v__"


# ---------------------------------------------------------------------------
# get_version
# ---------------------------------------------------------------------------

class TestGetVersion:
    def test_missing_package_returns_none(self):
        assert get_version({}, "missing", "ubuntu", "amd64") is None

    def test_returns_version_for_matching_target(self):
        md = {}
        add_version(md, "p", "1.0.0", "ubuntu", "amd64")
        assert get_version(md, "p", "ubuntu", "amd64") == "1.0.0"

    def test_returns_highest_version_for_target(self):
        md = {}
        add_version(md, "p", "1.0.0", "ubuntu", "amd64")
        add_version(md, "p", "1.1.0", "ubuntu", "amd64")
        add_version(md, "p", "1.0.5", "ubuntu", "amd64")
        assert get_version(md, "p", "ubuntu", "amd64") == "1.1.0"

    def test_no_matching_target_returns_none(self):
        md = {}
        add_version(md, "p", "1.0.0", "ubuntu", "amd64")
        assert get_version(md, "p", "debian", "amd64") is None


# ---------------------------------------------------------------------------
# remove_version
# ---------------------------------------------------------------------------

class TestRemoveVersion:
    def test_missing_package_returns_false(self):
        assert remove_version({}, "missing", "1.0.0") is False

    def test_missing_version_returns_false(self):
        md = {}
        add_version(md, "p", "1.0.0", "ubuntu", "amd64")
        assert remove_version(md, "p", "9.9.9") is False

    def test_removes_version_returns_true(self):
        md = {}
        add_version(md, "p", "1.0.0", "ubuntu", "amd64")
        result = remove_version(md, "p", "1.0.0")
        assert result is True
        assert "p" not in md  # last version → package removed

    def test_promotes_next_highest_when_removing_latest(self):
        md = {}
        add_version(md, "p", "1.0.0", "ubuntu", "amd64")
        add_version(md, "p", "1.1.0", "ubuntu", "amd64")
        add_version(md, "p", "1.2.0", "ubuntu", "amd64")
        remove_version(md, "p", "1.2.0")
        assert md["p"]["latest"] == "1.1.0"

    def test_removes_only_version_deletes_package(self):
        md = {}
        add_version(md, "p", "1.0.0", "ubuntu", "amd64")
        remove_version(md, "p", "1.0.0")
        assert "p" not in md

    def test_removing_non_latest_keeps_latest(self):
        md = {}
        add_version(md, "p", "1.0.0", "ubuntu", "amd64")
        add_version(md, "p", "1.1.0", "ubuntu", "amd64")
        remove_version(md, "p", "1.0.0")
        assert md["p"]["latest"] == "1.1.0"
        assert "1.0.0" not in md["p"]["versions"]


# ---------------------------------------------------------------------------
# safe_write_json
# ---------------------------------------------------------------------------

class TestSafeWriteJson:
    def test_writes_valid_json(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "out.json")
            data = {"key": "value", "num": 42}
            safe_write_json(path, data)
            with open(path) as f:
                loaded = json.load(f)
            assert loaded == data

    def test_creates_parent_directories(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "subdir", "nested", "out.json")
            safe_write_json(path, {"x": 1})
            assert os.path.exists(path)

    def test_no_temp_file_remains_after_success(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "out.json")
            safe_write_json(path, {})
            files = os.listdir(d)
            assert files == ["out.json"]

    def test_overwrites_existing_file(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "out.json")
            safe_write_json(path, {"v": 1})
            safe_write_json(path, {"v": 2})
            with open(path) as f:
                assert json.load(f) == {"v": 2}
