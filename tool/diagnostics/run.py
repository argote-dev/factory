#!/usr/bin/env python3
"""Assemble an unpublished diagnostic experiment against the current core."""

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tool/diagnostics"
BUILD = ROOT / ".dart_tool/diagnostics_prototype"


def run(*args):
    subprocess.run(args, cwd=BUILD, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["test", "benchmark"])
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.mode == "benchmark" and args.output is None:
        parser.error("benchmark requires --output")
    BUILD.mkdir(parents=True, exist_ok=True)
    core = ROOT / "packages/factory_core"
    shutil.copytree(core / "lib", BUILD / "lib", dirs_exist_ok=True)
    shutil.copy(core / "pubspec.yaml", BUILD / "pubspec.yaml")
    shutil.copy(core / "analysis_options.yaml", BUILD / "analysis_options.yaml")
    library = BUILD / "lib/factory_core.dart"
    library.write_text(library.read_text() + "\npart 'src/snapshot.dart';\n")
    shutil.copy(SOURCE / "snapshot.dart", BUILD / "lib/src/snapshot.dart")
    (BUILD / "test").mkdir(exist_ok=True)
    shutil.copy(SOURCE / "snapshot_test.dart", BUILD / "test/snapshot_test.dart")
    shutil.copy(SOURCE / "benchmark.dart", BUILD / "benchmark.dart")
    shutil.copy(SOURCE / "retention.dart", BUILD / "retention.dart")
    run("dart", "pub", "get")
    run("dart", "analyze")
    if args.mode == "test":
        run("dart", "test", "test/snapshot_test.dart")
        run("dart", "--enable-vm-service=0", "retention.dart")
        return
    executable = BUILD / ("benchmark.exe" if sys.platform == "win32" else "benchmark")
    run("dart", "compile", "exe", "benchmark.dart", "-o", str(executable))
    files = sorted((core / "lib").rglob("*.dart")) + sorted(SOURCE.glob("*.dart"))
    files.append(Path(__file__).resolve())
    evidence = {
        "commit": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "sdk": subprocess.check_output(["dart", "--version"], text=True).strip(),
        "sourceSha256": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                         for p in files},
        "runs": [json.loads(subprocess.check_output(
            [str(executable), str(index)], cwd=BUILD, text=True)) for index in range(3)],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(evidence, indent=2) + "\n")


if __name__ == "__main__":
    main()
