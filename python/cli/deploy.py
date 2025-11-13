"""Produce a production build of the React application."""

from __future__ import annotations

import argparse
import getpass
import sys
from pathlib import Path
from typing import Dict, Iterable, Tuple

from .utils import get_project_root, run_command

EnvRecord = Dict[str, str]
Prompt = Tuple[str, str, bool, bool, str | None]


def _parse_env_file(path: Path) -> EnvRecord:
    """Load KEY=VALUE pairs from an existing dotenv file."""

    values: EnvRecord = {}
    if not path.exists():
        return values

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, raw_value = line.split("=", 1)
        values[key.strip()] = raw_value
    return values


def _format_env_file(entries: Iterable[Tuple[str, str]]) -> str:
    """Serialise key/value pairs to dotenv format with a trailing newline."""

    lines = [f"{key}={value}" for key, value in entries]
    return "\n".join(lines) + "\n"


def _prompt_value(
    *,
    label: str,
    key: str,
    required: bool,
    secret: bool,
    default: str | None,
    existing: str | None,
    interactive: bool,
) -> str:
    """Collect a configuration value from the user, respecting defaults."""

    if not interactive:
        if existing:
            return existing
        if default is not None:
            return default
        if required:
            raise RuntimeError(
                f"Missing required value for {key}. Run the deployment command "
                "interactively to supply credentials."
            )
        return ""

    prompt_parts = [label]
    if existing and not secret:
        prompt_parts.append(f"(current: {existing})")
    elif existing and secret:
        prompt_parts.append("(press Enter to keep existing value)")
    elif default is not None:
        prompt_parts.append(f"[{default}]")

    prompt = " ".join(prompt_parts) + ": "

    while True:
        if secret:
            response = getpass.getpass(prompt)
        else:
            response = input(prompt)

        response = response.strip()

        if not response:
            if existing:
                return existing
            if default is not None:
                return default
            if not required:
                return ""
            print(f"{key} is required. Please provide a value.")
            continue
        return response


def ensure_env_files(project_root: Path, *, verbose: bool, dry_run: bool) -> None:
    """Prompt the operator for configuration values and write env files."""

    interactive = sys.stdin.isatty()

    env_path = project_root / ".env"
    current_env = _parse_env_file(env_path)

    prompts: Tuple[Prompt, ...] = (
        ("SNOWFLAKE_ACCOUNT", "Snowflake account identifier", True, False, None),
        ("SNOWFLAKE_USER", "Snowflake username", True, False, None),
        ("SNOWFLAKE_PASSWORD", "Snowflake user password", True, True, None),
        ("SNOWFLAKE_ROLE", "Snowflake role", False, False, "DATA_ENGINEER"),
        ("SNOWFLAKE_WAREHOUSE", "Snowflake warehouse", False, False, "SFE_REACT_AGENT_WH"),
        ("SNOWFLAKE_DATABASE", "Snowflake database", False, False, "SNOWFLAKE_EXAMPLE"),
        ("SNOWFLAKE_SCHEMA", "Snowflake schema", False, False, "REACT_AGENT_STAGE"),
        ("SNOWFLAKE_REGION", "Snowflake region (optional)", False, False, None),
        ("SNOWFLAKE_AGENT", "Cortex Agent name", True, False, None),
        ("SNOWFLAKE_PAT", "Programmatic Access Token", True, True, None),
        ("REACT_APP_BACKEND_URL", "React backend URL", False, False, "http://localhost:4000"),
        ("PORT", "Backend server port", False, False, "4000"),
        ("MAX_UPLOAD_MB", "Max upload size (MB)", False, False, "5"),
    )

    all_values: EnvRecord = {}
    for key, label, required, secret, default in prompts:
        value = _prompt_value(
            label=label,
            key=key,
            required=required,
            secret=secret,
            default=default,
            existing=current_env.get(key),
            interactive=interactive,
        )
        if value:
            all_values[key] = value

    if dry_run:
        print("Dry run: would write the following to", env_path)
        for key, value in all_values.items():
            print(f"{key}={value}")
        return

    env_path.write_text(
        _format_env_file(all_values.items()),
        encoding="utf-8",
    )
    if verbose:
        print(f"Wrote configuration to {env_path}")


def build_application(project_root: Path, *, verbose: bool, dry_run: bool) -> int:
    """Run ``npm run build`` from the repository root."""

    command = ["npm", "run", "build"]
    if dry_run:
        print("Dry run:", " ".join(command))
        return 0

    return run_command(command, cwd=project_root, verbose=verbose)


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
    """Entry point for the deploy command."""

    args = parse_args(argv)
    project_root = get_project_root()
    print(f"Project root: {project_root}")
    ensure_env_files(project_root, verbose=args.verbose, dry_run=args.dry_run)
    # The build step is now part of the standard `npm start` flow for development,
    # so we no longer call it explicitly here for the local run case.
    # return build_application(project_root, verbose=args.verbose, dry_run=args.dry_run)
    print("\nEnvironment configuration complete.")
    print("You can now run 'tools/02_start.sh' or 'tools\\02_start.bat' to start the application.")
    print("Use 'tools/03_status.sh' or 'tools\\03_status.bat' to check service status.")
    print("Use 'tools/04_stop.sh' or 'tools\\04_stop.bat' to stop all services.")
    return 0


if __name__ == "__main__":  # pragma: no cover - module entry point
    sys.exit(main())


__all__ = ["build_application", "ensure_env_files", "main", "parse_args"]

