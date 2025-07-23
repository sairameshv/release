#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

export KUBECTL=oc
export DEPLOY_DIR=deploy
export IMAGE_REGISTRY="${IMAGE_REGISTRY}"
export IMAGE_TAG="${IMAGE_TAG}"
export EMULATED_MODE=${EMULATED_MODE}

TOOLS_DIR=/tmp/bin
CONTROLLER_GEN_VERSION=v0.16.4
JQ_VERSION=jq-1.7
JQ_BINARY_URL="https://github.com/jqlang/jq/releases/download/${JQ_VERSION}/jq-$(go env GOOS)-$(go env GOARCH)"
JUST_VERSION=1.42.2
JUST_URL="https://github.com/casey/just/releases/download/${JUST_VERSION}/just-${JUST_VERSION}-x86_64-unknown-linux-musl.tar.gz"
PARALLEL_VERSION=20250622
PARALLEL_URL="https://ftp.gnu.org/gnu/parallel/parallel-${PARALLEL_VERSION}.tar.bz2"

# Install tools
echo "Installing tools to deploy instaslice-operator"
mkdir -p "${TOOLS_DIR}"
# controller-gen
curl -L --retry 5 \
"https://github.com/kubernetes-sigs/controller-tools/releases/download/${CONTROLLER_GEN_VERSION}/controller-gen-$(go env GOOS)-$(go env GOARCH)" \
-o "${TOOLS_DIR}/controller-gen" && chmod +x "${TOOLS_DIR}/controller-gen"
echo "   controller-gen installed"
# jq
curl -L --retry 5 "${JQ_BINARY_URL}" -o "${TOOLS_DIR}/jq" && chmod +x "${TOOLS_DIR}/jq"
echo "   jq installed"
# just
curl -L --retry 5 "${JUST_URL}" -o just.tar.gz
tar -xzf just.tar.gz -C "${TOOLS_DIR}" just
chmod +x "${TOOLS_DIR}/just"
rm just.tar.gz
echo "   just installed"

# parallel
curl -L --retry 5 "${PARALLEL_URL}" -o parallel.tar.bz2
tar -xjf parallel.tar.bz2
cd "parallel-${PARALLEL_VERSION}"
./configure --prefix="${TOOLS_DIR}"
make
make install
cd ..
rm -rf "parallel-${PARALLEL_VERSION}" parallel.tar.bz2
echo "   parallel installed"

export PATH="${TOOLS_DIR}:${PATH}"

export OPERATOR_IMAGE=${DAS_OPERATOR_IMG}
export WEBHOOK_IMAGE=${DAS_WEBHOOK_IMG}
export SCHEDULER_IMAGE=${DAS_SCHEDULER_IMG}
export DAEMONSET_IMAGE=${DAS_DAEMONSET_IMG}

echo "Deploying instaslice-operator and executing e2e test suite"
just test-e2e-ci
