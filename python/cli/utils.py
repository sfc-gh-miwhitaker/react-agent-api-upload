"""Shared helpers for command line utilities."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path
from typing import Mapping, MutableMapping, Sequence


def get_project_root() -> Path:
    """Return the absolute path to the repository root."""

    return Path(__file__).resolve().parents[2]


def run_command(
    command: Sequence[str],
    *,
    cwd: Path | None = None,
    env: Mapping[str, str] | None = None,
    verbose: bool = False,
) -> int:
    """Execute a subprocess command.

    Parameters
    ----------
    command:
        The command and arguments to execute.
    cwd:
        Optional working directory for the command.
    env:
        Optional environment variable overrides.
    verbose:
        When true, echo the command to stdout before execution.

    Returns
    -------
    int
        The subprocess return code.
    """

    if verbose:
        print("Running:", " ".join(command))

    process_env: MutableMapping[str, str] = dict(os.environ)
    if env:
        process_env.update(env)

    completed = subprocess.run(
        list(command),
        cwd=str(cwd) if cwd is not None else None,
        env=process_env,
        check=False,
    )
    return completed.returncode


__all__ = ["get_project_root", "run_command"]

