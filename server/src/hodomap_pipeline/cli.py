"""Command-line entry point for the HodoMap acquisition pipeline."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
from typing import Any, Dict, List, Optional

from hodomap_pipeline.acquisition import (
    AcquisitionSettings,
    is_due,
    run_refresh,
)
from hodomap_pipeline.registry import Registry
from hodomap_pipeline.state import StateStore


def _repository_root() -> Path:
    return Path(__file__).resolve().parents[3]


def _default_data_root() -> Path:
    return Path(
        os.environ.get(
            "HODOMAP_DATA_ROOT",
            str(Path.home() / ".local" / "share" / "hodomap"),
        )
    )


def build_parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(
        description="Bounded HodoMap source acquisition",
    )
    root.add_argument(
        "--registry",
        type=Path,
        default=_repository_root() / "data" / "operators" / "registry.json",
    )
    root.add_argument(
        "--state-db",
        type=Path,
        default=_default_data_root() / "acquisition.db",
    )
    commands = root.add_subparsers(dest="command", required=True)

    commands.add_parser("validate-registry")
    commands.add_parser("status")
    commands.add_parser("plan")

    refresh = commands.add_parser("refresh")
    refresh.add_argument("--force", action="store_true")
    refresh.add_argument("--source", action="append", dest="sources")
    refresh.add_argument("--max-sources", type=int)
    refresh.add_argument(
        "--artifact-root",
        type=Path,
        default=_default_data_root() / "artifacts",
    )
    refresh.add_argument(
        "--report-root",
        type=Path,
        default=Path(
            os.environ.get(
                "HODOMAP_REPORT_ROOT",
                str(Path.home() / ".local" / "state" / "hodomap" / "reports"),
            )
        ),
    )
    return root


def _settings() -> AcquisitionSettings:
    return AcquisitionSettings(
        contact_email=os.environ.get(
            "HODOMAP_CONTACT_EMAIL",
            "info@peterdsp.dev",
        ),
        max_requests=int(os.environ.get("HODOMAP_MAX_REQUESTS", "100")),
        minimum_host_interval_seconds=float(
            os.environ.get("HODOMAP_MIN_HOST_INTERVAL_SECONDS", "1.5")
        ),
        jitter_seconds=float(os.environ.get("HODOMAP_JITTER_SECONDS", "0.3")),
        timeout_seconds=float(os.environ.get("HODOMAP_TIMEOUT_SECONDS", "20")),
    )


def execute(args: argparse.Namespace) -> Dict[str, Any]:
    registry = Registry.load(args.registry)
    if args.command == "validate-registry":
        return {
            "valid": True,
            "registry": str(args.registry),
            "officialOperators": len(registry.operators),
            "sources": len(registry.sources),
            "enabledSources": len(registry.enabled_sources()),
            "verifiedAt": registry.verified_at,
        }

    with StateStore(args.state_db) as store:
        if args.command == "status":
            result = store.status()
            result["registrySources"] = len(registry.sources)
            result["enabledSources"] = len(registry.enabled_sources())
            return result
        if args.command == "plan":
            due = [
                target.source_id
                for target in registry.enabled_sources()
                if is_due(target, store.source_state(target.source_id))
            ]
            return {
                "dueCount": len(due),
                "dueSources": due,
                "usesCartesianProduct": False,
                "ticketingEnabled": any(
                    target.source_kind == "ticketing"
                    for target in registry.enabled_sources()
                ),
            }
        if args.command == "refresh":
            return run_refresh(
                store=store,
                targets=registry.sources,
                artifact_root=args.artifact_root,
                report_root=args.report_root,
                settings=_settings(),
                force=args.force,
                source_ids=args.sources,
                max_sources=args.max_sources,
            )
    raise AssertionError("unreachable")


def main(argv: Optional[List[str]] = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        result = execute(args)
    except Exception as exc:
        print(
            json.dumps(
                {
                    "status": "failed",
                    "error": "{}: {}".format(type(exc).__name__, exc),
                },
                ensure_ascii=False,
                indent=2,
                sort_keys=True,
            )
        )
        return 1
    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return 0
