"""Unit tests for core/stage.py CLI (called via subprocess)."""
import json
import os
import subprocess
import sys
import tempfile

import pytest

REPO_ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
STAGE_SCRIPT = os.path.join(REPO_ROOT, "core", "stage.py")


def run_stage(*args, metadata_file=None, out_dir=None, env=None):
    """Helper: invoke stage.py with given args and return (returncode, stdout, stderr)."""
    with tempfile.TemporaryDirectory() as d:
        mf = metadata_file or os.path.join(d, "metadata", "index.json")
        od = out_dir or os.path.join(d, "out")
        cmd = [
            sys.executable,
            STAGE_SCRIPT,
            *args,
            "--metadata-file", mf,
            "--out-dir", od,
        ]
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            env={**os.environ, "PYTHONUNBUFFERED": "1", **(env or {})},
        )
        return result.returncode, result.stdout, result.stderr, mf, od


class TestStageCLI:
    def test_new_package_creates_index_at_1_0_0(self):
        with tempfile.TemporaryDirectory() as d:
            mf = os.path.join(d, "metadata", "index.json")
            od = os.path.join(d, "out")
            rc, out, err, _, _ = run_stage("myprog", "new", "-b", "ubuntu_amd64",
                                            metadata_file=mf, out_dir=od)
            assert rc == 0, f"stage.py failed:\n{err}"
            with open(mf) as f:
                idx = json.load(f)
            assert "myprog" in idx
            assert idx["myprog"]["latest"] == "1.0.0"

    def test_package_name_is_last_stdout_line(self):
        with tempfile.TemporaryDirectory() as d:
            mf = os.path.join(d, "metadata", "index.json")
            od = os.path.join(d, "out")
            rc, out, err, _, _ = run_stage("myprog", "new", "-b", "ubuntu_amd64",
                                            metadata_file=mf, out_dir=od)
            assert rc == 0, err
            pkg_name = out.strip().splitlines()[-1]
            assert pkg_name == "myprog_v1.0.0_ubuntu_amd64"

    def test_patch_bump_increments_version(self):
        with tempfile.TemporaryDirectory() as d:
            mf = os.path.join(d, "metadata", "index.json")
            od = os.path.join(d, "out")
            # First: create at 1.0.0
            run_stage("myprog", "new", "-b", "ubuntu_amd64", metadata_file=mf, out_dir=od)
            # Second: patch bump
            rc, out, err, _, _ = run_stage("myprog", "patch", "-b", "ubuntu_amd64",
                                            metadata_file=mf, out_dir=od)
            assert rc == 0, err
            with open(mf) as f:
                idx = json.load(f)
            assert idx["myprog"]["latest"] == "1.0.1"

    def test_new_on_existing_package_fails(self):
        with tempfile.TemporaryDirectory() as d:
            mf = os.path.join(d, "metadata", "index.json")
            od = os.path.join(d, "out")
            run_stage("myprog", "new", "-b", "ubuntu_amd64", metadata_file=mf, out_dir=od)
            rc, out, err, _, _ = run_stage("myprog", "new", "-b", "ubuntu_amd64",
                                            metadata_file=mf, out_dir=od)
            assert rc != 0

    def test_explicit_version_override(self):
        with tempfile.TemporaryDirectory() as d:
            mf = os.path.join(d, "metadata", "index.json")
            od = os.path.join(d, "out")
            rc, out, err, _, _ = run_stage("myprog", "new", "-b", "ubuntu_amd64",
                                            "--version", "3.1.4",
                                            metadata_file=mf, out_dir=od)
            assert rc == 0, err
            with open(mf) as f:
                idx = json.load(f)
            assert "3.1.4" in idx["myprog"]["versions"]

    def test_invalid_explicit_version_fails(self):
        with tempfile.TemporaryDirectory() as d:
            mf = os.path.join(d, "metadata", "index.json")
            od = os.path.join(d, "out")
            rc, out, err, _, _ = run_stage("myprog", "new", "-b", "ubuntu_amd64",
                                            "--version", "notvalid",
                                            metadata_file=mf, out_dir=od)
            assert rc != 0

    def test_builder_os_arch_reflected_in_pkg_name(self):
        with tempfile.TemporaryDirectory() as d:
            mf = os.path.join(d, "metadata", "index.json")
            od = os.path.join(d, "out")
            rc, out, err, _, _ = run_stage("myprog", "new", "-b", "arch_amd64",
                                            metadata_file=mf, out_dir=od)
            assert rc == 0, err
            pkg_name = out.strip().splitlines()[-1]
            assert "arch_amd64" in pkg_name

    def test_md_json_file_created_in_out_dir(self):
        with tempfile.TemporaryDirectory() as d:
            mf = os.path.join(d, "metadata", "index.json")
            od = os.path.join(d, "out")
            rc, out, err, _, _ = run_stage("myprog", "new", "-b", "ubuntu_amd64",
                                            metadata_file=mf, out_dir=od)
            assert rc == 0, err
            pkg_name = out.strip().splitlines()[-1]
            md_file = os.path.join(od, f"{pkg_name}_md.json")
            assert os.path.exists(md_file)
            with open(md_file) as f:
                pkg_md = json.load(f)
            assert pkg_md["name"] == "myprog"
            assert pkg_md["version"] == "1.0.0"
            assert pkg_md["os"] == "ubuntu"
            assert pkg_md["arch"] == "amd64"

    def test_existing_package_new_arch_minor_bump_from_global_latest(self):
        with tempfile.TemporaryDirectory() as d:
            mf = os.path.join(d, "metadata", "index.json")
            od = os.path.join(d, "out")
            # Create package at ubuntu_amd64 (lands at 1.0.0)
            run_stage("myprog", "new", "-b", "ubuntu_amd64", metadata_file=mf, out_dir=od)
            # Stage a minor bump for a brand-new builder
            rc, out, err, _, _ = run_stage("myprog", "minor", "-b", "arch_amd64",
                                            metadata_file=mf, out_dir=od)
            assert rc == 0, err
            with open(mf) as f:
                idx = json.load(f)
            # Bumped from global latest (1.0.0) -> 1.1.0, not reset to 1.0.0
            assert idx["myprog"]["latest"] == "1.1.0"
            assert "1.1.0" in idx["myprog"]["versions"]
            assert "arch_amd64" in idx["myprog"]["versions"]["1.1.0"]["targets"]
            pkg_name = out.strip().splitlines()[-1]
            assert pkg_name == "myprog_v1.1.0_arch_amd64"

    def test_restage_same_version_same_arch_exits_cleanly_no_pkg_name(self):
        with tempfile.TemporaryDirectory() as d:
            mf = os.path.join(d, "metadata", "index.json")
            od = os.path.join(d, "out")
            # Stage explicit version 2.0.0
            run_stage("myprog", "new", "-b", "ubuntu_amd64", "--version", "2.0.0",
                      metadata_file=mf, out_dir=od)
            # Re-stage the exact same version+arch
            rc, out, err, _, _ = run_stage("myprog", "patch", "-b", "ubuntu_amd64",
                                            "--version", "2.0.0",
                                            metadata_file=mf, out_dir=od)
            # Exit cleanly (no-op, not a build failure)
            assert rc == 0, err
            # Package name must NOT be emitted so the pipeline does not proceed
            assert "myprog_v2.0.0_ubuntu_amd64" not in out
            assert "has been staged" not in out
            assert "nothing to do" in out

    def test_metadata_file_and_out_dir_flags_are_respected(self):
        with tempfile.TemporaryDirectory() as d:
            custom_mf = os.path.join(d, "custom", "my_index.json")
            custom_od = os.path.join(d, "custom_out")
            rc, out, err, _, _ = run_stage("myprog", "new", "-b", "ubuntu_amd64",
                                            metadata_file=custom_mf, out_dir=custom_od)
            assert rc == 0, err
            assert os.path.exists(custom_mf)
            assert os.path.exists(custom_od)
