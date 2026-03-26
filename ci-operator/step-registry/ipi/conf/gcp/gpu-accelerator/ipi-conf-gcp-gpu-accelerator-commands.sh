#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

CONFIG="${SHARED_DIR}/install-config.yaml"
PATCH="${SHARED_DIR}/gpu_accelerator.yaml.patch"

# Configure GPU accelerators for compute nodes
if [[ -n "${COMPUTE_GPU_TYPE:-}" ]] && [[ -n "${COMPUTE_GPU_COUNT:-}" ]]; then
  cat > "${PATCH}" << EOF
compute:
- name: worker
  platform:
    gcp:
      accelerators:
      - type: ${COMPUTE_GPU_TYPE}
        count: ${COMPUTE_GPU_COUNT}
EOF
  yq-go m -x -i "${CONFIG}" "${PATCH}"
  echo "GPU accelerator configuration added to compute nodes:"
  yq-go r "${CONFIG}" compute
fi

# Configure GPU accelerators for control plane nodes (rare but possible)
if [[ -n "${CONTROL_PLANE_GPU_TYPE:-}" ]] && [[ -n "${CONTROL_PLANE_GPU_COUNT:-}" ]]; then
  cat > "${PATCH}" << EOF
controlPlane:
  name: master
  platform:
    gcp:
      accelerators:
      - type: ${CONTROL_PLANE_GPU_TYPE}
        count: ${CONTROL_PLANE_GPU_COUNT}
EOF
  yq-go m -x -i "${CONFIG}" "${PATCH}"
  echo "GPU accelerator configuration added to control plane nodes:"
  yq-go r "${CONFIG}" controlPlane
fi
