#!/usr/bin/env bash
set -euo pipefail

# Download model files manually (fallback)
# Run on the Olares server directly

MODEL_DIR="${1:-/olares/rootfs/userspace/pvc-userspace-aimighty-phbiddku99qy4cuz/Data/vllmgemma426ba4bnvfp4vision/models}"
HF_BASE="${MODEL_DIR}/huggingface/hub"
MODEL_REPO="bg-digitalservices/Gemma-4-26B-A4B-it-NVFP4"

echo "Downloading model via HuggingFace Hub..."
mkdir -p "${HF_BASE}"

huggingface-cli download \
  "${MODEL_REPO}" \
  --local-dir "${HF_BASE}/models--bg-digitalservices--Gemma-4-26B-A4B-it-NVFP4" \
  --local-dir-use-symlinks False

echo "Done. Files in:"
ls -lh "${HF_BASE}/models--bg-digitalservices--Gemma-4-26B-A4B-it-NVFP4/" 2>/dev/null || echo "Check HF_HOME path"
