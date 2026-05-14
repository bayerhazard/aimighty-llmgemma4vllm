#!/usr/bin/env bash
set -euo pipefail

# Cleanup Gemma 4 26B Vision NVFP4 deployment from Olares
# Usage: ./cleanup.sh olares@172.20.0.4

if [ $# -lt 1 ]; then
  echo "Usage: $0 <ssh-host>"
  echo "Example: $0 olares@172.20.0.4"
  exit 1
fi

SSH_HOST="$1"
NAMESPACE="vllmgemma426ba4bnvfp4vision-aimighty"
APP="vllmgemma426ba4bnvfp4vision"

echo "=== Cleaning up ${APP} from ${SSH_HOST} ==="

# Delete namespace (cascades to deployment, pods, services, configmaps)
ssh "${SSH_HOST}" "kubectl delete namespace ${NAMESPACE} 2>/dev/null || true"
echo "[OK] Namespace ${NAMESPACE} deleted"

# Delete model files on disk
MODEL_PATH="/olares/rootfs/userspace/pvc-userspace-aimighty-phbiddku99qy4cuz/Data/${APP}/models"
ssh "${SSH_HOST}" "rm -rf ${MODEL_PATH} 2>/dev/null || true"
echo "[OK] Model files deleted from ${MODEL_PATH}"

echo ""
echo "=== Cleanup complete ==="
