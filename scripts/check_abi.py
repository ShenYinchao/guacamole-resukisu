"""Compare exported symbol CRCs; this is not a runtime boot test."""
import json
import sys
from pathlib import Path

def read_symvers(path):
    result = {}
    for line in Path(path).read_text().splitlines():
        parts = line.split()
        if len(parts) >= 3:
            result[parts[1]] = parts[0]
    if len(result) < 100:
        raise RuntimeError(f"Unexpected or empty Module.symvers: {path}")
    return result

baseline = read_symvers(sys.argv[1])
rooted = read_symvers(sys.argv[2])
changes = [name for name, crc in baseline.items() if rooted.get(name) != crc]
report = {
    "baseline_symbols": len(baseline),
    "rooted_symbols": len(rooted),
    "missing_or_changed_symbols": changes,
    "passed": not changes,
    "limitation": "Compares the two source builds, not the installed vendor modules. Boot and Wi-Fi must still be tested."
}
Path(sys.argv[3]).write_text(json.dumps(report, indent=2) + "\n")
if changes:
    raise SystemExit("Module ABI changed; do not use the kernel. Inspect abi-report.json.")
print(f"Unchanged CRCs for {len(baseline)} existing exported symbols.")
