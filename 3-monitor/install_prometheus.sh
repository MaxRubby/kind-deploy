#!/bin/bash
# 在三个 Kind 集群中安装 Prometheus
set -e

# Setup Paths
BASE_DIR=$(cd "$(dirname "$0")" && pwd)
BIN_DIR="$BASE_DIR/1-bin"
export PATH=$BIN_DIR:$PATH

echo "=== 在所有集群中安装 Prometheus ==="

# 集群列表
CLUSTERS=("kind-hub-cluster-a10" "kind-cluster-a10-01" "kind-cluster-a10-02")

# 添加 helm repo
echo "Adding Prometheus helm repo..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo update

for ctx in "${CLUSTERS[@]}"; do
    echo ""
    echo "=========================================="
    echo "Installing Prometheus on: $ctx"
    echo "=========================================="
    
    # Switch context
    kubectl config use-context $ctx
    
    # 等待节点就绪
    echo "Waiting for nodes to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=120s
    
    # 删除旧的安装（如果存在）
    echo "Cleaning up any existing Prometheus installation..."
    helm uninstall prometheus 2>/dev/null || true
    kubectl delete pvc -l app.kubernetes.io/name=prometheus 2>/dev/null || true
    
    # 安装 Prometheus，增加超时时间到 10 分钟
    echo "Installing Prometheus (this may take a few minutes)..."
    helm upgrade --install prometheus prometheus-community/prometheus \
        --set server.service.type=NodePort \
        --set server.service.nodePort=30001 \
        --set server.persistentVolume.enabled=false \
        --set alertmanager.persistentVolume.enabled=false \
        --timeout 10m \
        --wait
    
    # 验证 Pod 状态
    echo "Verifying Prometheus pods..."
    kubectl get pods -l app.kubernetes.io/name=prometheus
    
    echo "Prometheus installed successfully on $ctx!"
done

echo ""
echo "=== All Prometheus installations complete! ==="
echo ""
echo "Access Prometheus on each cluster:"
echo "  - hub-cluster-a10:  http://localhost:31001"
echo "  - cluster-a10-01:   http://localhost:30001"  
echo "  - cluster-a10-02:   http://localhost:30101"
