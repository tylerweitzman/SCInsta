#!/usr/bin/env python3
"""Inspect the running sideloaded Hinge on Apple silicon; no UI actions or HTTP requests."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import shlex
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pid", type=int, help="Defaults to the single running Hinge.app/Hinge process")
    parser.add_argument("--query", action="append", default=[], help="Controller class / stored-field path; repeatable")
    parser.add_argument("--depth", type=int, default=1, choices=range(5))
    args = parser.parse_args()
    source = Path(__file__).resolve().parent
    output_dir = source.parents[1] / "dumps" / "runtime-probe"
    output_dir.mkdir(parents=True, exist_ok=True)
    library = output_dir / "RuntimeProbe.dylib"
    if not library.exists() or library.stat().st_mtime < (source / "RuntimeProbe.swift").stat().st_mtime:
        sdk = subprocess.check_output(["rtk", "proxy", "xcrun", "--sdk", "iphoneos", "--show-sdk-path"], text=True).strip()
        subprocess.run(["rtk", "proxy", "xcrun", "swiftc", "-swift-version", "5", "-emit-library", "-module-name", "HingeRuntimeProbe", "-target", "arm64-apple-ios16.0", "-sdk", sdk, str(source / "RuntimeProbe.swift"), "-o", str(library)], check=True)
        subprocess.run(["rtk", "proxy", "codesign", "--force", "--sign", "-", str(library)], check=True)
    if args.pid is None:
        processes = subprocess.check_output(["rtk", "proxy", "ps", "-axo", "pid,comm"], text=True)
        matches = [int(line.split()[0]) for line in processes.splitlines() if line.rstrip().endswith("/Hinge.app/Hinge")]
        if len(matches) != 1:
            parser.error("Expected one running Hinge process; pass --pid explicitly")
        args.pid = matches[0]
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    output = output_dir / (timestamp + ".json")
    config = output_dir / (timestamp + ".config.json")
    queries = args.query or ["Hinge.DiscoveryProfileViewController", "Hinge.DiscoveryProfileViewController/presenter", "Hinge.DiscoveryProfileViewController/presenter/interactor"]
    config.write_text(json.dumps({"pid": args.pid, "library": str(library), "queries": queries, "depth": args.depth, "output": str(output)}))
    command = ["rtk", "proxy", "lldb", "--batch", "-o", "command script import " + shlex.quote(str(source / "lldb_driver.py")), "-o", "hinge-probe " + shlex.quote(str(config))]
    completed = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (output_dir / (timestamp + ".log")).write_text(completed.stdout)
    print(completed.stdout)
    if completed.returncode or not output.exists():
        raise SystemExit(completed.returncode or 1)
    report = json.loads(output.read_text())
    if report["errors"] or not report.get("detached"):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
