"""Reject unexpected changes to the original kernel configuration."""
import json
import sys
from pathlib import Path

def read_config(path):
    values = {}
    for line in Path(path).read_text().splitlines():
        if line.startswith("CONFIG_") and "=" in line:
            key, value = line.split("=", 1)
            values[key] = value
        elif line.startswith("# CONFIG_") and line.endswith(" is not set"):
            values[line[2:-11]] = "n"
    return values

original = read_config(sys.argv[1])
current = read_config(sys.argv[2])
allow_root = sys.argv[3] == "root"
changes = {key: [original.get(key), current.get(key)]
           for key in sorted(original.keys() | current.keys())
           if original.get(key, "n") != current.get(key, "n")
           and not (allow_root and key.startswith("CONFIG_KSU"))}
Path(sys.argv[4]).write_text(json.dumps(changes, indent=2) + "\n")
if changes:
    raise SystemExit("Unexpected configuration changes; inspect config report.")
if allow_root and current.get("CONFIG_KSU") != "y":
    raise SystemExit("ReSukiSU was not enabled.")
print("Original kernel configuration preserved.")
