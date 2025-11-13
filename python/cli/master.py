"""
This module provides a command-line interface for setting up the project,
configuring secrets, and running the application. It is the main entry
point for all automation.
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

# Add project root to the Python path to allow absolute imports
project_root = Path(__file__).resolve().parents[2]
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))

from python.cli import deploy, describe_agent, setup


def _run_script(script_path: Path, *args: str) -> int:
    """Execute a shell or batch script."""
    if not script_path.exists():
        print(f"Error: Script not found at {script_path}")
        return 1
    
    command = [str(script_path), *args]
    try:
        process = subprocess.run(command, check=True)
        return process.returncode
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        print(f"Error running script {script_path.name}: {e}")
        # On Unix, the file might not be executable
        if sys.platform != "win32" and isinstance(e, FileNotFoundError):
             print(f"Hint: Try running 'chmod +x {script_path}'")
        return 1


def main() -> int:
    """Main command dispatcher."""
    parser = argparse.ArgumentParser(description="Master control script for the React Agent application.")
    subparsers = parser.add_subparsers(dest="command", required=True, help="Available commands")

    # Setup command
    setup_parser = subparsers.add_parser("setup", help="Install all project dependencies (Python and Node.js).")
    setup_parser.set_defaults(func=lambda args: setup.main(None))

    # Configure command
    config_parser = subparsers.add_parser("configure", help="Interactively create the .env file for secrets.")
    config_parser.set_defaults(func=lambda args: deploy.main(None))

    # Run command
    run_parser = subparsers.add_parser("run", help="Start the backend and frontend servers.")
    run_parser.set_defaults(func=lambda args: _run_script(project_root / "tools" / f"02_start.{'bat' if sys.platform == 'win32' else 'sh'}"))

    # Describe agent command
    describe_parser = subparsers.add_parser("describe-agent", help="Fetch and display the description of the configured Cortex Agent.")
    describe_parser.set_defaults(func=lambda args: describe_agent.main(None))

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    # Ensure PYTHONPATH is set for discoverability if run directly
    os.environ["PYTHONPATH"] = str(project_root)
    sys.exit(main())


__all__ = [
    "do_build",
    "do_deploy",
    "do_describe_agent",
    "do_curl_agent",
    "do_setup",
    "do_test",
    "do_up",
    "main",
    "parse_args",
]

