#!/usr/bin/env python3
"""Capture three fresh macOS profile processes; Python standard library only."""

import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import time
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]


def command(*args):
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()


def save(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def rpc(uri, method, **params):
    query = urllib.parse.urlencode(params)
    with urllib.request.urlopen(f"{uri}{method}?{query}", timeout=1800) as reply:
        response = json.load(reply)
    if "error" in response:
        raise RuntimeError(response["error"])
    return response["result"]


def capture(output, run):
    directory = output / f"run-{run}"
    directory.mkdir()
    uri_file = directory / "service-uri.txt"
    args = ["flutter", "run", "-d", "macos", "--profile", "--no-dds",
            "-t", "lib/propagation_profile.dart",
            f"--vmservice-out-file={uri_file}"]
    with (directory / "launch.log").open("w") as log:
        process = subprocess.Popen(args, cwd=ROOT / "example", stdout=log,
                                   stderr=subprocess.STDOUT, stdin=subprocess.PIPE,
                                   text=True, start_new_session=True)
        try:
            deadline = time.monotonic() + 300
            while not uri_file.exists():
                if process.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError(f"Profile launch failed; inspect {directory}")
                time.sleep(.5)
            address = urllib.parse.urlsplit(uri_file.read_text().strip())
            uri = urllib.parse.urlunsplit((
                "http", address.netloc, address.path.removesuffix("ws"), "", ""))
            vm = rpc(uri, "getVM")
            isolate = next(item["id"] for item in vm["isolates"]
                           if item["name"] == "main")
            while "ext.factory.profilePropagation" not in rpc(
                    uri, "getIsolate", isolateId=isolate).get("extensionRPCs", []):
                if time.monotonic() > deadline:
                    raise RuntimeError("Propagation extension did not register")
                time.sleep(.1)
            result = {"run": run, "pid": vm["pid"], "command": args, "results": []}
            # Reverse AB order in run 2 to expose (not eliminate) order effects.
            for trace in ([False, True] if run != 2 else [True, False]):
                rpc(uri, "setVMTimelineFlags",
                    recordedStreams="[Dart]" if trace else "[]")
                for size in (10, 100, 1000):
                    rpc(uri, "clearVMTimeline")
                    rpc(uri, "clearCpuSamples", isolateId=isolate)
                    start = rpc(uri, "getVMTimelineMicros")["timestamp"]
                    measured = rpc(uri, "ext.factory.profilePropagation",
                                   isolateId=isolate, size=size,
                                   trace=str(trace).lower())
                    end = rpc(uri, "getVMTimelineMicros")["timestamp"]
                    result["results"].append(measured)
                    save(directory / "results.json", result)
                    print(f"run={run} trace={trace} size={size} "
                          f"p50={measured['p50Us']:.1f}us "
                          f"p95={measured['p95Us']:.1f}us", flush=True)
                    if trace and size == 1000:
                        timeline = rpc(uri, "getVMTimeline")
                        cpu = rpc(uri, "getCpuSamples", isolateId=isolate,
                                  timeOriginMicros=start, timeExtentMicros=end-start)
                        for name, data in (("timeline", timeline), ("cpu", cpu)):
                            with gzip.open(directory / f"{name}.json.gz", "wt") as f:
                                json.dump(data, f)
            return result
        finally:
            if process.poll() is None:
                try:
                    process.communicate("q\n", timeout=20)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGTERM)
                    process.wait(timeout=20)
            # VM Service URI carries a local authentication token.
            uri_file.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="New external artifact directory")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    harness = ROOT / "example/lib/propagation_profile.dart"
    metadata = {
        "commit": command("git", "rev-parse", "HEAD"),
        "trackedDiff": command("git", "diff", "HEAD", "--stat"),
        "harnessSha256": hashlib.sha256(harness.read_bytes()).hexdigest(),
        "runnerSha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "sdk": command("flutter", "--version"),
        "os": command("sw_vers"),
        "hardware": command("sysctl", "-n", "machdep.cpu.brand_string"),
        "memoryBytes": command("sysctl", "-n", "hw.memsize"),
        "power": command("pmset", "-g", "batt"),
        "powerSettings": command("pmset", "-g", "custom"),
        "startedUtc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    save(output / "environment.json", metadata)
    runs = [capture(output, run) for run in (1, 2, 3)]
    save(output / "baseline.json", {"environment": metadata, "runs": runs})


if __name__ == "__main__":
    main()
