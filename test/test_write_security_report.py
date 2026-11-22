"""Unit tests for scripts/macos/write_security_report.py (MOD-13, CWE-23)."""

import importlib.util
import json
import os
import sys
import tempfile
from unittest import mock

import pytest

MODULE_PATH = os.path.realpath(
    os.path.join(os.path.dirname(__file__), "..", "scripts", "macos", "write_security_report.py")
)
SPEC = importlib.util.spec_from_file_location("write_security_report", MODULE_PATH)
wsr = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(wsr)


def test_safe_path_rejects_traversal_flags_and_outside_paths():
    """Verify safe_path refuses '..', leading dashes, NUL bytes, and outside roots."""
    with pytest.raises(ValueError, match="traversal"):
        wsr.safe_path("../etc/passwd")
    with pytest.raises(ValueError, match="unsafe CLI"):
        wsr.safe_path("--option-injection")
    with pytest.raises(ValueError, match="invalid path"):
        wsr.safe_path("valid\x00evil")
    with pytest.raises(ValueError, match="outside the allowed"):
        wsr.safe_path("/etc/hosts")


def test_safe_path_rejects_symlink_escape():
    """Verify safe_path resolves symlinks and rejects targets outside allowed roots."""
    with tempfile.TemporaryDirectory() as tmp_dir:
        escape_link = os.path.join(tmp_dir, "escape.json")
        os.symlink("/etc/hosts", escape_link)
        with pytest.raises(ValueError, match="outside the allowed"):
            wsr.safe_path(escape_link, allowed_roots=(tmp_dir,))


def test_end_to_end_report_generation():
    """Verify main() writes a complete security report from validated build files."""
    with tempfile.TemporaryDirectory(prefix="security report ") as tmp_dir:
        gates_file = os.path.join(tmp_dir, "summary.env")
        bundled_file = os.path.join(tmp_dir, "bundled.json")
        static_file = os.path.join(tmp_dir, "static.json")
        dmg_file = os.path.join(tmp_dir, "ModFS_1.0.4_macos-arm64.dmg")
        out_file = os.path.join(tmp_dir, "security_report.md")

        with open(gates_file, "w", encoding="utf-8") as fh:
            fh.write("GATE_RESULT=PASSED\nGATE_DATE=2026-11-21\nGATE_COMMIT=abc1234\nSNYK_CODE='No issues'\n")
        with open(bundled_file, "w", encoding="utf-8") as fh:
            json.dump([], fh)
        with open(static_file, "w", encoding="utf-8") as fh:
            json.dump(
                [{"name": "pcre2", "version": "10.49", "license": "BSD-3-Clause", "sha256": "deadbeef"}],
                fh,
            )
        with open(dmg_file, "wb") as fh:
            fh.write(b"fake-dmg-payload")

        argv = [
            "write_security_report.py",
            "--version",
            "1.0.4+40",
            "--gates",
            gates_file,
            "--bundled",
            bundled_file,
            "--static-libs",
            static_file,
            "--dmg",
            dmg_file,
            "--deployment-target",
            "14.0",
            "--output",
            out_file,
        ]
        with (
            mock.patch.object(sys, "argv", argv),
            mock.patch.object(wsr, "_allowed_roots", return_value=(os.path.realpath(tmp_dir),)),
            mock.patch.object(wsr, "command_output", return_value="Authority=Developer ID\nThe validate action worked!"),
        ):
            wsr.main()

        with open(out_file, encoding="utf-8") as fh:
            report = fh.read()
        assert "# ModFS 1.0.4+40" in report
        assert "| pcre2 | 10.49 | BSD-3-Clause | `deadbeef` |" in report
