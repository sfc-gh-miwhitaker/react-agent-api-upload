"""Unit tests for CLI helper utilities."""

from __future__ import annotations

from pathlib import Path

import sys

import pytest

from python.cli import setup
from python.cli.describe_agent import build_agent_url, normalise_account
from python.cli.utils import get_project_root
from python.cli import master as master_cli


def test_get_project_root_contains_package_json() -> None:
    """The project root should contain the Node package manifest."""

    root = get_project_root()
    assert (root / "package.json").exists()


@pytest.mark.parametrize(
    "raw, expected",
    [
        ("example-xy123", "example-xy123.snowflakecomputing.com"),
        ("example-xy123.snowflakecomputing.com", "example-xy123.snowflakecomputing.com"),
    ],
)
def test_normalise_account_appends_suffix(raw: str, expected: str) -> None:
    """Ensure the account host name is well formed."""

    assert normalise_account(raw) == expected


def test_build_agent_url_encodes_components() -> None:
    """Encoded identifiers should appear in the final URL."""

    url = build_agent_url("example", "My DB", "Public", "Agent 1")
    assert url == (
        "https://example.snowflakecomputing.com/api/v2/databases/My+DB/"
        "schemas/Public/agents/Agent+1"
    )


def test_get_venv_python_respects_platform(tmp_path: Path) -> None:
    """Derived Python path should follow platform conventions."""

    venv_dir = tmp_path / "venv"
    expected = (
        venv_dir / "Scripts" / "python.exe"
        if sys.platform.startswith("win")
        else venv_dir / "bin" / "python"
    )
    assert setup.get_venv_python(venv_dir) == expected


def test_ensure_virtualenv_invokes_run_command(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    """When the venv is missing, the helper should call run_command."""

    captured: dict[str, list[str]] = {}

    def fake_run(command: list[str], cwd: Path | None, verbose: bool) -> int:
        captured["command"] = command
        return 0

    monkeypatch.setattr(setup, "run_command", fake_run)

    result = setup.ensure_virtualenv(tmp_path, verbose=False, dry_run=False)
    assert result == 0
    assert captured["command"][0:3] == [sys.executable, "-m", "venv"]


def test_ensure_virtualenv_skips_when_exists(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    """If the directory already exists, no subprocess should run."""

    (tmp_path / "venv").mkdir()

    def fake_run(*_: object) -> int:  # pragma: no cover - should not be called
        raise AssertionError("run_command should not be invoked when venv exists")

    monkeypatch.setattr(setup, "run_command", fake_run)

    assert setup.ensure_virtualenv(tmp_path, verbose=True, dry_run=False) == 0


def test_install_python_dependencies_invokes_pip(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    """The pip installation command should target the virtual environment interpreter."""

    requirements = tmp_path / "python"
    requirements.mkdir()
    requirements_file = requirements / "requirements.txt"
    requirements_file.write_text("pytest\n", encoding="utf-8")

    venv_dir = tmp_path / "venv"
    if sys.platform.startswith("win"):
        python_path = venv_dir / "Scripts"
        python_path.mkdir(parents=True)
        interpreter = python_path / "python.exe"
    else:
        python_path = venv_dir / "bin"
        python_path.mkdir(parents=True)
        interpreter = python_path / "python"
    interpreter.write_text("", encoding="utf-8")

    captured: dict[str, list[str]] = {}

    def fake_run(command: list[str], cwd: Path | None, verbose: bool) -> int:
        captured["command"] = command
        return 0

    monkeypatch.setattr(setup, "run_command", fake_run)

    result = setup.install_python_dependencies(tmp_path, verbose=False, dry_run=False)
    assert result == 0
    assert captured["command"][0] == str(interpreter)
    assert captured["command"][-2:] == ["-r", str(requirements_file)]


def test_install_node_dependencies_invokes_npm(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    """npm install should be executed from the project root."""

    captured: dict[str, list[str]] = {}

    def fake_run(command: list[str], cwd: Path | None, verbose: bool) -> int:
        captured["command"] = command
        captured["cwd"] = [str(cwd)] if cwd else []
        return 0

    monkeypatch.setattr(setup, "run_command", fake_run)

    result = setup.install_node_dependencies(tmp_path, verbose=True, dry_run=False)
    assert result == 0
    assert captured["command"] == ["npm", "install"]
    assert captured["cwd"] == [str(tmp_path)]


def test_install_backend_dependencies_skips_when_missing(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    """Backend install should no-op if the directory is absent."""

    def fake_run(*_args: object, **_kwargs: object) -> int:  # pragma: no cover - should not run
        raise AssertionError("run_command must not be called when server/ is missing")

    monkeypatch.setattr(setup, "run_command", fake_run)
    assert setup.install_backend_dependencies(tmp_path, verbose=True, dry_run=False) == 0


def test_install_backend_dependencies_runs_install(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    """Backend install should execute npm install when directory exists."""

    server_dir = tmp_path / "server"
    server_dir.mkdir()

    captured: dict[str, list[str]] = {}

    def fake_run(command: list[str], cwd: Path | None, verbose: bool) -> int:
        captured["command"] = command
        captured["cwd"] = [str(cwd)] if cwd else []
        return 0

    monkeypatch.setattr(setup, "run_command", fake_run)

    result = setup.install_backend_dependencies(tmp_path, verbose=False, dry_run=False)
    assert result == 0
    assert captured["command"] == ["npm", "install"]
    assert captured["cwd"] == [str(server_dir)]


def test_master_parse_args_help_and_commands() -> None:
    """Master CLI exposes expected subcommands."""

    # Basic parse should succeed for representative commands
    for argv in (
        ["setup"],
        ["build"],
        ["test"],
        ["deploy"],
        ["up"],
        ["all"],
        ["ci"],
        ["describe-agent"],
        ["server-test"],
        ["curl-agent", "ping"],
    ):
        ns = master_cli.parse_args(argv + ["--dry-run"])
        assert ns.command == argv[0]

