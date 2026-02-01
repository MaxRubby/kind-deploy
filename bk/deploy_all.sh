#!/bin/bash
set -e

# Ensure binaries are in PATH
export PATH=$HOME/bin:$PATH

echo "Starting deployment..."

# Function to check if command exists
check_cmd() {
    if ! command -v $1 &> /dev/null; then
        echo "$1 could not be found"
        exit 1
    fi
}

check_cmd kind
check_cmd kubectl
check_cmd helm
check_cmd docker

# 1. Create Clusters
echo "Creating hub-cluster..."
kind create cluster --config kind-hub.yaml --image kindest/node:v1.25.3 || echo "Cluster hub-cluster might already exist"

# echo "Creating test-new..."
# kind create cluster --config kind3-1.yaml --image kindest/node:v1.25.3 || echo "Cluster test-new might already exist"

# echo "Creating test-new-02..."
# kind create cluster --config kind3-2.yaml --image kindest/node:v1.25.3 || echo "Cluster test-new-02 might already exist"

# 2. Install Prometheus and RBAC for each cluster
# Context names are usually kind-<cluster-name>
CLUSTERS=("kind-hub-cluster" "kind-test-new" "kind-test-new-02")

# Add helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
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
    # We set the NodePort to 30002 to match the kind config mapping
    helm upgrade --install prometheus prometheus-community/prometheus \
        --set server.service.type=NodePort \
        --set server.service.nodePort=30002

    # Verify Pods running
    echo "Waiting for Prometheus pods to be ready..."
    kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=prometheus --timeout=300s

    # Apply RBAC and print info
    echo "Applying RBAC configuration..."
    ./get-all-rbac-token.sh
    
    echo "Finished configuration for $ctx"
done

echo "Deployment all complete!"
