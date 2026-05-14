#!/usr/bin/env bash
set -euo pipefail

# Deploy Gemma 4 26B A4B Vision (NVFP4 + vLLM) on Olares
# Usage: ./deploy.sh olares@172.20.0.4
# Prerequisites: SSH key-based auth to Olares server

if [ $# -lt 1 ]; then
  echo "Usage: $0 <ssh-host>"
  echo "Example: $0 olares@172.20.0.4"
  exit 1
fi

SSH_HOST="$1"
NAMESPACE="vllmgemma426ba4bnvfp4vision-aimighty"
APP="vllmgemma426ba4bnvfp4vision"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Deploying ${APP} to ${SSH_HOST} ==="

# Create namespace
ssh "${SSH_HOST}" "kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml" | kubectl apply -f -
echo "[OK] Namespace ${NAMESPACE} created/verified"

# Create ConfigMap vllm-env
sed 's/vllmgemma426ba4bnvfp4vision-aimighty/'"${NAMESPACE}"'/' "${SCRIPT_DIR}/kubernetes/configmap.yaml" | \
  ssh "${SSH_HOST}" "kubectl apply -f -"
echo "[OK] ConfigMap vllm-env applied"

# Upload patch files and create ConfigMaps
scp "${SCRIPT_DIR}/kubernetes/patches/gemma4.py" "${SSH_HOST}:/tmp/gemma4_patch.py"
ssh "${SSH_HOST}" "kubectl create configmap gemma4-patched -n ${NAMESPACE} --from-file=gemma4.py=/tmp/gemma4_patch.py --dry-run=client -o yaml | kubectl apply -f - && rm /tmp/gemma4_patch.py"
echo "[OK] ConfigMap gemma4-patched created"

scp "${SCRIPT_DIR}/kubernetes/patches/fused_moe_layer.py" "${SSH_HOST}:/tmp/fused_moe_layer.py"
ssh "${SSH_HOST}" "kubectl create configmap fused-moe-patched -n ${NAMESPACE} --from-file=layer.py=/tmp/fused_moe_layer.py --dry-run=client -o yaml | kubectl apply -f - && rm /tmp/fused_moe_layer.py"
echo "[OK] ConfigMap fused-moe-patched created"

# Apply Deployment
sed -e 's/vllmgemma426ba4bnvfp4vision-aimighty/'"${NAMESPACE}"'/' \
    -e 's/vllmgemma426ba4bnvfp4vision/'"${APP}"'/' \
    "${SCRIPT_DIR}/kubernetes/deployment.yaml" | \
  ssh "${SSH_HOST}" "kubectl apply -f -"
echo "[OK] Deployment applied"

echo ""
echo "=== Deployment complete ==="
echo "Namespace: ${NAMESPACE}"
echo "Monitor: kubectl get pods -n ${NAMESPACE} -w"
echo "Startup takes ~15 min (model download 15 GB + warmup)"
