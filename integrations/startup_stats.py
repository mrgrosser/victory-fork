"""Summarize one checkpoint launch. All startup timings use a fixed elapsed window."""
import argparse
import json
import math
import re
from datetime import datetime
from pathlib import Path


def launch_work(directory, seconds):
    manifest = json.loads((directory / "manifest.json").read_text(encoding="utf-8-sig"))
    result = json.loads((directory / "result.json").read_text(encoding="utf-8-sig"))
    start = datetime.fromisoformat(result["startUtc"]).timestamp()
    if not math.isfinite(seconds) or seconds <= 0:
        raise ValueError("seconds must be finite and positive")
    first_present = None
    presents = compiles = failed_compiles = conversion_us = 0
    hits = misses = latest = None
    end = start + seconds
    with (directory / "err.log").open(encoding="utf-8", errors="replace") as log:
        for line in log:
            if "checkpoint_bench: " not in line:
                continue
            stamp = datetime.fromisoformat(line.split()[0]).timestamp()
            latest = stamp if latest is None else max(stamp, latest)
            if stamp < start or stamp >= end:
                continue
            event = line.split("checkpoint_bench: ", 1)[1]
            if event.startswith("present "):
                first_present = stamp if first_present is None else min(first_present, stamp)
                presents += 1
            elif event.startswith("cache conversion ") and 'converter="shader.dxil"' in event:
                elapsed = int(re.search(r"\belapsed_us=(\d+)", event).group(1))
                conversion_us += elapsed
                compiles += 1
                failed_compiles += int("success=false" in event)
            elif event.startswith("shader totals "):
                totals = dict(re.findall(r"(\w+)=(\d+)", event))
                hits, misses = int(totals["hits"]), int(totals["misses"])
    if latest is None or latest < end:
        raise ValueError("log does not cover the requested startup window")
    if hits is None:
        raise ValueError("no shader cache totals in this window")
    if misses and compiles == 0:
        raise ValueError("missing converter timings for recorded cache misses")
    return {
        "scenario": manifest["scenario"], "cache_mode": manifest["cacheMode"],
        "renderer_sha256": manifest["renderer"], "seconds": seconds,
        "first_present_s": None if first_present is None else round(first_present - start, 3),
        "presents": presents, "shader_hits_last_sample": hits, "shader_misses_last_sample": misses,
        "completed_shader_conversions": compiles, "failed_shader_conversions": failed_compiles,
        "shader_conversion_worker_s": round(conversion_us / 1e6, 3),
        "client_size": (directory / "client-size.txt").read_text(encoding="utf-8-sig").strip(),
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--seconds", type=float, default=60)
    args = parser.parse_args()
    print(json.dumps(launch_work(args.directory, args.seconds), indent=2))
