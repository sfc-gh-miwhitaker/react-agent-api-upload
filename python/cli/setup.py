"""Install project dependencies and prepare the local environment."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from .utils import get_project_root, run_command


def get_venv_python(venv_dir: Path) -> Path:
    """Return the Python interpreter inside the virtual environment."""

    if sys.platform.startswith("win"):
        return venv_dir / "Scripts" / "python.exe"
    return venv_dir / "bin" / "python"


def ensure_virtualenv(project_root: Path, *, verbose: bool, dry_run: bool) -> int:
    """Create the project's virtual environment if it does not exist."""

    venv_dir = project_root / "venv"
    if venv_dir.exists():
        if verbose:
            print(f"Virtual environment already present at {venv_dir}")
        return 0

    command = [sys.executable, "-m", "venv", str(venv_dir)]
    if dry_run:
        print("Dry run:", " ".join(command))
        return 0

    return run_command(command, cwd=project_root, verbose=verbose)


def install_python_dependencies(project_root: Path, *, verbose: bool, dry_run: bool) -> int:
    """Install Python dependencies into the virtual environment."""

    requirements = project_root / "python" / "requirements.txt"
    if not requirements.exists():
        if verbose:
            print(f"No Python requirements found at {requirements}; skipping installation")
        return 0

    venv_dir = project_root / "venv"
    python_exe = get_venv_python(venv_dir)
    command = [str(python_exe), "-m", "pip", "install", "-r", str(requirements)]

    if dry_run:
        print("Dry run:", " ".join(command))
        return 0

    if verbose and not python_exe.exists():
        print(f"Warning: expected interpreter not found at {python_exe}; attempting installation anyway")

    return run_command(command, cwd=project_root, verbose=verbose)


def install_node_dependencies(project_root: Path, *, verbose: bool, dry_run: bool) -> int:
    """Run ``npm install`` from the repository root."""

    command = ["npm", "install"]
    if dry_run:
        print("Dry run:", " ".join(command))
        return 0

    return run_command(command, cwd=project_root, verbose=verbose)


def install_backend_dependencies(project_root: Path, *, verbose: bool, dry_run: bool) -> int:
    """Install Node dependencies for the backend service."""

    server_dir = project_root / "server"
    if not server_dir.exists():
        if verbose:
            print(f"Skipping backend install; directory not found: {server_dir}")
        return 0

    command = ["npm", "install"]
    if dry_run:
        print("Dry run:", " ".join(command), f"(cwd={server_dir})")
        return 0

    return run_command(command, cwd=server_dir, verbose=verbose)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    """Parse command line arguments."""

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Echo commands before execution.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show commands without executing them.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Entry point for the setup command."""

    args = parse_args(argv)
    project_root = get_project_root()
    print(f"Project root: {project_root}")

    steps = [
        ensure_virtualenv,
        install_python_dependencies,
        install_node_dependencies,
        install_backend_dependencies,
    ]

    for step in steps:
        result = step(project_root, verbose=args.verbose, dry_run=args.dry_run)
        if result != 0:
            return result

    return 0


if __name__ == "__main__":  # pragma: no cover - module entry point
    sys.exit(main())


__all__ = [
    "ensure_virtualenv",
    "get_venv_python",
    "install_backend_dependencies",
    "install_node_dependencies",
    "install_python_dependencies",
    "main",
    "parse_args",
]

