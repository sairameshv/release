#!/bin/bash
set -o nounset
set -o errexit
set -o pipefail

echo "========================================="
echo "Upstream Kubernetes DRA E2E Tests"
echo "========================================="
echo "Test Focus: ${DRA_TEST_FOCUS}"
echo ""

export KUBECONFIG="${SHARED_DIR}/kubeconfig"
export ARTIFACTS="${ARTIFACT_DIR}"

# Wait for cluster to be ready
echo "Waiting for cluster to be ready..."
oc wait --for=condition=Ready nodes --all --timeout=10m

# Verify GPU nodes
echo ""
echo "Verifying GPU nodes..."
GPU_NODES=$(oc get nodes -l nvidia.com/gpu.present=true -o name 2>/dev/null | wc -l)
echo "GPU nodes found: ${GPU_NODES}"

if [ "${GPU_NODES}" -eq 0 ]; then
  echo "ERROR: No GPU nodes found!"
  echo ""
  echo "All nodes and labels:"
  oc get nodes --show-labels
  exit 1
fi

echo "✓ Found ${GPU_NODES} GPU node(s)"
echo ""
oc get nodes -l nvidia.com/gpu.present=true -o wide

# Verify NVIDIA DRA driver is installed
echo ""
echo "Verifying NVIDIA DRA driver..."
if ! oc get deviceclass nvidia.com/gpu &>/dev/null; then
  echo "ERROR: DeviceClass nvidia.com/gpu not found!"
  echo "NVIDIA DRA driver must be installed before running tests"
  exit 1
fi

echo "✓ DeviceClass: nvidia.com/gpu exists"

# Check ResourceSlices
RESOURCE_SLICES=$(oc get resourceslice -o name 2>/dev/null | wc -l)
echo "✓ ResourceSlices: ${RESOURCE_SLICES}"

if [ "${RESOURCE_SLICES}" -eq 0 ]; then
  echo "WARNING: No ResourceSlices found, DRA driver may not be functioning correctly"
fi

# Verify feature gates if testing Partitionable Devices
if echo "${DRA_TEST_FOCUS}" | grep -q "DRAPartitionableDevices"; then
  echo ""
  echo "Verifying DRAPartitionableDevices feature gate..."
  FEATURE_SET=$(oc get featuregate cluster -o jsonpath='{.spec.featureSet}' 2>/dev/null || echo "")
  ENABLED_GATES=$(oc get featuregate cluster -o jsonpath='{.spec.customNoUpgrade.enabled}' 2>/dev/null || echo "[]")

  echo "FeatureSet: ${FEATURE_SET}"
  echo "Enabled Gates: ${ENABLED_GATES}"

  if ! echo "${ENABLED_GATES}" | grep -q "DRAPartitionableDevices"; then
    echo "ERROR: DRAPartitionableDevices feature gate is not enabled!"
    echo "Please enable the feature gate before running partitionable devices tests"
    exit 1
  fi

  echo "✓ DRAPartitionableDevices feature gate is enabled"
fi

# Build skip pattern (exclude [DRA] from common skips - we want to run DRA tests!)
PLATFORM="${CLUSTER_TYPE:-gcp}"
NETWORK_SKIPS="\[Skipped:Network/OVNKubernetes\]|\[Feature:Networking-IPv6\]|\[Feature:IPv6DualStack.*\]|\[Feature:SCTPConnectivity\]"
COMMON_SKIPS="\[Slow\]|\[Disruptive\]|\[Flaky\]|\[Disabled:.+\]|\[Skipped:${PLATFORM}\]|\[DedicatedJob\]|${NETWORK_SKIPS}"

# Set test args
export KUBE_E2E_TEST_ARGS="-focus=${DRA_TEST_FOCUS} -skip=${COMMON_SKIPS}"

echo ""
echo "========================================="
echo "Running Kubernetes E2E Tests"
echo "========================================="
echo "Test arguments: ${KUBE_E2E_TEST_ARGS}"
echo ""

# Run upstream Kubernetes e2e tests
# test-kubernetes-e2e.sh is provided by the kubernetes-tests image
test-kubernetes-e2e.sh

echo ""
echo "========================================="
echo "Tests Completed Successfully"
echo "========================================="
