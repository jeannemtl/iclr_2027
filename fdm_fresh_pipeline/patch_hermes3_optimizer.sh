#!/bin/bash
# Patches eidetic_hermes3_fdm_e2e_fresh.py to use bitsandbytes AdamW8bit
# instead of torch.optim.AdamW, fixing the OOM caused by fp32 optimizer
# state (~24GB) for a 3B-parameter model on a 32GB GPU.
#
# Usage:
#   bash patch_hermes3_optimizer.sh

set -e

TARGET=/workspace/eidetic_hermes3_fdm_e2e_fresh.py

if [ ! -f "$TARGET" ]; then
    echo "ERROR: $TARGET not found."
    exit 1
fi

echo "Installing bitsandbytes..."
pip install bitsandbytes --break-system-packages 2>/dev/null || pip install bitsandbytes

echo "Backing up original script to ${TARGET}.bak"
cp "$TARGET" "${TARGET}.bak"

echo "Patching optimizer line..."
python3 << 'PYEOF'
import re

path = "/workspace/eidetic_hermes3_fdm_e2e_fresh.py"
with open(path) as f:
    content = f.read()

old_line = "        optimizer = AdamW(model.parameters(), lr=stage['lr'] * LR_SCALE)"
new_block = """        try:
            import bitsandbytes as bnb
            optimizer = bnb.optim.AdamW8bit(model.parameters(), lr=stage['lr'] * LR_SCALE)
            print("  Using bitsandbytes AdamW8bit optimizer")
        except ImportError:
            print("  WARNING: bitsandbytes not available, falling back to full-precision AdamW (may OOM on 3B model)")
            optimizer = AdamW(model.parameters(), lr=stage['lr'] * LR_SCALE)"""

if old_line not in content:
    print("ERROR: expected optimizer line not found verbatim. No changes made.")
    print("Expected to find:")
    print(old_line)
    raise SystemExit(1)

content = content.replace(old_line, new_block)

with open(path, "w") as f:
    f.write(content)

print("Patched successfully.")
PYEOF

echo ""
echo "Done. Diff against backup:"
diff "${TARGET}.bak" "$TARGET" || true

echo ""
echo "Clearing stale checkpoints from the earlier MAX_LENGTH=1024 OOM run..."
rm -rf /workspace/checkpoints_fdm_fresh_hermes3/*
echo "Cleared."

echo ""
echo "Ready. Run:"
echo "  python3 eidetic_hermes3_fdm_e2e_fresh.py train 2>&1 | tee /workspace/hermes3_fresh_train_log.txt"
