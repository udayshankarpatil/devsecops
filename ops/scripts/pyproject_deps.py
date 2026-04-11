#!/usr/bin/env python3
"""Print all dependencies from a pyproject.toml to stdout, one per line.

Includes both runtime and dev (optional) dependencies. Output is compatible
with pip-audit -r /dev/stdin.

Usage:
    python ops/scripts/pyproject_deps.py services/api/pyproject.toml
"""

import sys
import tomllib
from pathlib import Path

path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("pyproject.toml")
with path.open("rb") as f:
    d = tomllib.load(f)

deps = d["project"]["dependencies"]
dev = d["project"].get("optional-dependencies", {}).get("dev", [])
print("\n".join(deps + dev))
