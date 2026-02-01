#!/bin/bash
set -e

# Setup Paths
BASE_DIR=$(cd "$(dirname "$0")" && pwd)
BIN_DIR="$BASE_DIR/1-bin"
CONFIG_DIR="$BASE_DIR/2-configs"
RBAC_DIR="$BASE_DIR/4-rbac"
OPS_DIR="$BASE_DIR/5-ops"

# Ensure binaries are in PATH
export PATH=$BIN_DIR:$PATH

echo "Using binaries from: $BIN_DIR"
echo "Starting deployment..."

# Function to check if command exists
check_cmd() {
    if ! command -v $1 &> /dev/null; then
        echo "Error: $1 could not be found. Please ensure it is installed in 1-bin/"
        exit 1
    fi
}

check_cmd kind
check_cmd kubectl
check_cmd helm

# Check for Docker
if ! docker ps > /dev/null 2>&1; then
   echo "ERROR: Docker is not running or not accessible."
   echo "Please fix your docker installation before running this script."
   echo "Try running: sudo rm /etc/systemd/system/docker.service.d/override.conf && sudo systemctl restart docker"
   exit 1
fi

# 1. Create Clusters
# 使用 kindest/node:v1.27.3 镜像，对 cgroup v1 系统有更好的支持
KIND_IMAGE="kindest/node:v1.27.3"

echo "Creating hub-cluster-a10..."
kind delete cluster --name hub-cluster-a10 || true
kind create cluster --config "$CONFIG_DIR/kind-hub.yaml" --image $KIND_IMAGE --retain 

echo "Creating cluster-a10-01..."
kind delete cluster --name cluster-a10-01 || true
kind create cluster --config "$CONFIG_DIR/kind3-1.yaml" --image $KIND_IMAGE --retain 

echo "Creating cluster-a10-02..."
kind delete cluster --name cluster-a10-02 || true
kind create cluster --config "$CONFIG_DIR/kind3-2.yaml" --image $KIND_IMAGE --retain 

# 2. Install Prometheus and RBAC for each cluster
# Context names are usually kind-<cluster-name>
CLUSTERS=("kind-hub-cluster-a10" "kind-cluster-a10-01" "kind-cluster-a10-02")

# Add helm repo if needed
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo update

for ctx in "${CLUSTERS[@]}"; do
    echo "--------------------------------------------------"
    echo "Configuring cluster: $ctx"
    
    # Switch context
    kubectl config use-context $ctx
    
    # Wait for node readiness (simple check)
    echo "Waiting for nodes..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s

    # Install Prometheus
    echo "Installing/Upgrading Prometheus..."
    # We set the NodePort to 30001 to match the kind config mapping
    helm upgrade --install prometheus prometheus-community/prometheus \
        --set server.service.type=NodePort \
        --set server.service.nodePort=30001 \
        --wait

    # Verify Pods running
    echo "Waiting for Prometheus pods to be ready..."
    kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=prometheus --timeout=300s

    # Apply RBAC and print info
    echo "Applying RBAC configuration..."
    
    # We execute the script in its directory context or pass paths
    # Here we are calling it from current dir, but the script expects to find rbac file relative to it
    # We'll just execute it and ensure it can find the file.
    # The script uses `../4-rbac/all-rbac.yaml`, so we must run it from `5-ops` directory.
    
    pushd "$OPS_DIR" > /dev/null
    ./get-all-rbac-token.sh
    popd > /dev/null
    
    echo "Finished configuration for $ctx"
done

echo "Deployment all complete!"
