"""Fetch metadata for a Snowflake Cortex Agent via the REST API."""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from typing import Any, Dict


def normalise_account(account: str) -> str:
    """Ensure the Snowflake account includes the host suffix."""

    trimmed = account.strip()
    if not trimmed:
        raise ValueError("Snowflake account is required.")
    if trimmed.endswith(".snowflakecomputing.com"):
        return trimmed
    return f"{trimmed}.snowflakecomputing.com"


def build_agent_url(account: str, database: str, schema: str, agent: str) -> str:
    """Construct the REST endpoint for the describe request."""

    host = normalise_account(account)
    base = f"https://{host}"
    path = "/".join(
        [
            "api",
            "v2",
            "databases",
            urllib.parse.quote_plus(database.strip()),
            "schemas",
            urllib.parse.quote_plus(schema.strip()),
            "agents",
            urllib.parse.quote_plus(agent.strip()),
        ]
    )
    return f"{base}/{path}"


def fetch_agent_metadata(url: str, token: str, *, verbose: bool) -> Dict[str, Any]:
    """Perform the HTTP GET request."""

    headers = {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token.strip()}",
    }
    request = urllib.request.Request(url, headers=headers, method="GET")

    if verbose:
        print(f"GET {url}")

    try:
        with urllib.request.urlopen(request) as response:  # type: ignore[arg-type]
            payload = response.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="ignore")
        message = detail or exc.reason or "HTTP error"
        raise RuntimeError(f"Snowflake API error {exc.code}: {message}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"Failed to reach Snowflake endpoint: {exc.reason}") from exc

    return json.loads(payload)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    """Parse command line arguments."""

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--account", default=os.environ.get("SNOWFLAKE_ACCOUNT", ""))
    parser.add_argument("--database", default=os.environ.get("SNOWFLAKE_DATABASE", ""))
    parser.add_argument("--schema", default=os.environ.get("SNOWFLAKE_SCHEMA", ""))
    parser.add_argument("--agent", default=os.environ.get("SNOWFLAKE_AGENT", ""))
    parser.add_argument(
        "--token",
        default=os.environ.get("SNOWFLAKE_PAT", os.environ.get("SNOWFLAKE_TOKEN", "")),
        help="Programmatic access token or bearer token for the API.",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Echo the request being executed.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show the resolved URL but do not call the API.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Entry point for describing a Cortex Agent."""

    args = parse_args(argv)

    if not args.account:
        raise SystemExit("Snowflake account is required (use --account or SNOWFLAKE_ACCOUNT).")
    if not args.database:
        raise SystemExit("Snowflake database is required (use --database or SNOWFLAKE_DATABASE).")
    if not args.schema:
        raise SystemExit("Snowflake schema is required (use --schema or SNOWFLAKE_SCHEMA).")
    if not args.agent:
        raise SystemExit("Cortex agent name is required (use --agent or SNOWFLAKE_AGENT).")
    if not args.token:
        raise SystemExit("Programmatic access token is required (use --token or SNOWFLAKE_PAT).")

    url = build_agent_url(args.account, args.database, args.schema, args.agent)

    if args.dry_run:
        print("Dry run: would call", url)
        return 0

    result = fetch_agent_metadata(url, args.token, verbose=args.verbose)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":  # pragma: no cover - module entry point
    sys.exit(main())


__all__ = [
    "build_agent_url",
    "fetch_agent_metadata",
    "main",
    "normalise_account",
    "parse_args",
]

