#!/usr/bin/env python3
"""Auditable, repeatable KMP Swift source reorganization.

The manifest is deliberately explicit. Run without arguments to review the
plan, `--apply` to atomically move every source, and `--verify` afterwards to
prove destinations and contents match the manifest.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
MIGRATIONS: tuple[tuple[str, str], ...] = (
    ("Deadliner/Data/Persistence/KMP/KMPPersistenceRuntime.swift", "Deadliner/Core/Persistence/KMPPersistenceRuntime.swift"),
    ("Deadliner/Data/Persistence/KMP/KMPPersistenceFeatureFlags.swift", "Deadliner/Core/Persistence/KMPPersistenceFeatureFlags.swift"),
    ("Deadliner/Data/Persistence/KMP/KMPSharedDatabaseLocation.swift", "Deadliner/Core/Persistence/KMP/KMPSharedDatabaseLocation.swift"),
    ("Deadliner/Data/Persistence/KMP/CategoryMigrationSnapshot.swift", "Deadliner/Core/Persistence/Migration/CategoryMigrationSnapshot.swift"),
    ("Deadliner/Data/Persistence/KMP/KMPCategoryShadowImporter.swift", "Deadliner/Core/Persistence/Migration/KMPCategoryShadowImporter.swift"),
    ("Deadliner/Data/Persistence/KMP/KMPTaskHabitShadowImporter.swift", "Deadliner/Core/Persistence/Migration/KMPTaskHabitShadowImporter.swift"),
    ("Deadliner/Data/Persistence/KMP/LegacyCategoryMigrationReader.swift", "Deadliner/Core/Persistence/Migration/LegacyCategoryMigrationReader.swift"),
    ("Deadliner/Data/Persistence/KMP/LegacyKMPIdentity.swift", "Deadliner/Core/Persistence/Migration/LegacyKMPIdentity.swift"),
    ("Deadliner/Data/Persistence/KMP/LegacyTaskHabitMigrationReader.swift", "Deadliner/Core/Persistence/Migration/LegacyTaskHabitMigrationReader.swift"),
    ("Deadliner/Data/Persistence/KMP/TaskHabitMigrationSnapshot.swift", "Deadliner/Core/Persistence/Migration/TaskHabitMigrationSnapshot.swift"),
    ("Deadliner/Data/Persistence/KMP/KMPTaskStore.swift", "Deadliner/Data/Persistence/Task/KMPTaskStore.swift"),
    ("Deadliner/Data/Persistence/KMP/KMPHabitStore.swift", "Deadliner/Data/Persistence/Habit/KMPHabitStore.swift"),
    ("Deadliner/Data/Persistence/KMP/KMPTaskCategoryStore.swift", "Deadliner/Data/Persistence/Category/KMPTaskCategoryStore.swift"),
    ("Deadliner/Data/Persistence/KMP/KMPCaptureStore.swift", "Deadliner/Features/Capture/Persistence/KMPCaptureStore.swift"),
    ("Deadliner/Data/Persistence/KMP/KMPMemoryStore.swift", "Deadliner/Features/Main/Persistence/KMPMemoryStore.swift"),
    ("Deadliner/Data/Persistence/KMP/KMPTaskPresentationStore.swift", "Deadliner/Features/Home/Persistence/KMPTaskPresentationStore.swift"),
    ("Deadliner/Data/Persistence/KMP/KMPHabitPresentationStore.swift", "Deadliner/Features/Home/Persistence/KMPHabitPresentationStore.swift"),
    ("Deadliner/Data/Persistence/KMP/KMPTaskListViewModelBridge.swift", "Deadliner/Features/Home/Bridge/KMPTaskListViewModelBridge.swift"),
    ("Deadliner/Data/Persistence/KMP/KMPHabitListViewModelBridge.swift", "Deadliner/Features/Home/Bridge/KMPHabitListViewModelBridge.swift"),
    ("Deadliner/Data/Persistence/KMP/KMPOverviewViewModelBridge.swift", "Deadliner/Features/Overview/Bridge/KMPOverviewViewModelBridge.swift"),
)


def digest(file_path: Path) -> str:
    return hashlib.sha256(file_path.read_bytes()).hexdigest()


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def describe(source: Path, destination: Path, sha256: str | None) -> None:
    print(json.dumps({"source": str(source.relative_to(ROOT)), "destination": str(destination.relative_to(ROOT)), "sha256": sha256}, ensure_ascii=False))


def apply_state() -> str:
    source_present = [source for source, _ in MIGRATIONS if (ROOT / source).is_file()]
    destination_present = [destination for _, destination in MIGRATIONS if (ROOT / destination).is_file()]
    if len(source_present) == len(MIGRATIONS) and not destination_present:
        return "pending"
    if not source_present and len(destination_present) == len(MIGRATIONS):
        return "complete"
    detail = {
        "presentSources": source_present,
        "presentDestinations": destination_present,
        "expectedCount": len(MIGRATIONS),
    }
    fail(f"partial or conflicting migration state: {json.dumps(detail, ensure_ascii=False)}")


def remove_empty_legacy_directory() -> None:
    legacy_directory = ROOT / "Deadliner/Data/Persistence/KMP"
    if legacy_directory.is_dir() and not any(legacy_directory.iterdir()):
        legacy_directory.rmdir()


def dry_run() -> None:
    for source_text, destination_text in MIGRATIONS:
        source, destination = ROOT / source_text, ROOT / destination_text
        describe(source, destination, digest(source) if source.is_file() else None)


def apply() -> None:
    if apply_state() == "complete":
        remove_empty_legacy_directory()
        verify()
        return
    for source_text, destination_text in MIGRATIONS:
        source, destination = ROOT / source_text, ROOT / destination_text
        before = digest(source)
        destination.parent.mkdir(parents=True, exist_ok=True)
        os.replace(source, destination)
        after = digest(destination)
        if before != after:
            fail(f"content changed while moving {source_text}")
        describe(source, destination, after)
    remove_empty_legacy_directory()


def verify() -> None:
    errors: list[str] = []
    for source_text, destination_text in MIGRATIONS:
        source, destination = ROOT / source_text, ROOT / destination_text
        if source.exists():
            errors.append(f"source still exists: {source_text}")
        if not destination.is_file():
            errors.append(f"destination missing: {destination_text}")
            continue
        describe(source, destination, digest(destination))
    old_folder = ROOT / "Deadliner/Data/Persistence/KMP"
    remaining = sorted(str(item.relative_to(ROOT)) for item in old_folder.glob("*.swift")) if old_folder.exists() else []
    if remaining:
        errors.append(f"legacy KMP directory still contains Swift sources: {remaining}")
    if errors:
        fail("; ".join(errors))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--apply", action="store_true", help="perform all manifest moves")
    mode.add_argument("--verify", action="store_true", help="verify a completed move")
    args = parser.parse_args()
    if args.apply:
        apply()
    elif args.verify:
        verify()
    else:
        if apply_state() == "complete":
            verify()
        else:
            dry_run()


if __name__ == "__main__":
    main()
