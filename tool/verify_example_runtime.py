#!/usr/bin/env python3
"""Run the example on one real target and retain commands, logs and identity."""

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", required=True, help="Exact flutter devices ID")
    parser.add_argument("--output", required=True, type=Path, help="New evidence directory")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    evidence = {
        "started_utc": datetime.now(timezone.utc).isoformat(),
        "device": args.device,
        "mode": "debug",
        "commands": [],
    }

    def run(name, command, cwd=root):
        print(f"{name}: {' '.join(command)}", flush=True)
        with (output / f"{name}.log").open("w") as log:
            result = subprocess.run(command, cwd=cwd, stdout=log, stderr=subprocess.STDOUT)
        evidence["commands"].append({
            "argv": command, "cwd": str(cwd.relative_to(root)),
            "exit_code": result.returncode, "log": f"{name}.log",
        })
        return result.returncode

    try:
        for name, command in [
            ("commit", ["git", "rev-parse", "HEAD"]),
            ("status", ["git", "status", "--porcelain"]),
            ("diff", ["git", "diff", "HEAD", "--", "example", "lib", "packages", "tool/verify_example_runtime.py"]),
            ("sdk", ["flutter", "--version", "--machine"]),
            ("devices", ["flutter", "devices", "--machine"]),
        ]:
            if run(name, command):
                raise SystemExit(f"Could not capture {name}; see {output}")
        command = ["flutter", "drive", "--debug", "--no-pub", "--timeout=180",
                   "--driver=test_driver/integration_test.dart",
                   "--target=integration_test/profile_flow_test.dart", "-d", args.device]
        if args.device == "chrome":
            command.append("--no-headless")
        code = run("run", command, root / "example")
        evidence["result"] = "passed" if code == 0 else "failed"
        raise SystemExit(code)
    finally:
        evidence["finished_utc"] = datetime.now(timezone.utc).isoformat()
        (output / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")
        print(f"Evidence: {output}", flush=True)


if __name__ == "__main__":
    main()
