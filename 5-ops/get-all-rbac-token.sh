#!/bin/bash
# Note: This script is executed by the main deploy script which already has kubectl in path
# and context set correctly.

# 应用配置
echo "创建 ServiceAccount 和 Token..."
kubectl apply -f ../4-rbac/all-rbac.yaml

# 等待 Secret 创建完成
echo "等待 Token 生成..."
sleep 3

# 获取 token
echo "获取 Token..."
TOKEN=$(kubectl -n kube-system get secret drl-scheduler-remote -o jsonpath='{.data.token}' | base64 --decode)

if [ -z "$TOKEN" ]; then
    echo "错误：无法获取 Token"
    exit 1
fi

echo "Token 获取成功 (Partial): ${TOKEN:0:10}..."

# 获取API服务器地址
API_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
echo -e "\nAPI Server 地址："
echo "$API_SERVER"

# 获取 Prometheus 服务信息
echo -e "\n获取 Prometheus 信息..."
# Try to get Prometheus info, handle if it's not ready or different
PROMETHEUS_PORT=$(kubectl get svc prometheus-server -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "Unknown")
PROMETHEUS_NODE_PORT=$(kubectl get svc prometheus-server -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "Unknown")
PROMETHEUS_CLUSTER_IP=$(kubectl get svc prometheus-server -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "Unknown")

if [ "$PROMETHEUS_PORT" != "Unknown" ]; then
    echo "Prometheus 集群内访问地址: http://$PROMETHEUS_CLUSTER_IP:$PROMETHEUS_PORT"
    if [ ! -z "$PROMETHEUS_NODE_PORT" ]; then
        HOST_IP=$(echo $API_SERVER | sed 's|https://\(.*\):[0-9]*|\1|')
        NODE_PORT=$PROMETHEUS_NODE_PORT
        echo "Prometheus NodePort 访问地址: http://${HOST_IP}:${NODE_PORT}"
    fi
else
    echo "Prometheus service not found or not ready."
fi

echo -e "\n配置示例："
echo "{
    \"isKind\": true,
    \"remoteHost\": \"$(echo $API_SERVER | sed 's|https://\(.*\):[0-9]*|\1|')\",
    \"kindPort\": $(echo $API_SERVER | sed 's|.*:\([0-9]*\)|\1|'),
    \"token\": \"$TOKEN\",
    \"apiServer\": \"$API_SERVER\",
    \"prometheusUrl\": \"http://$PROMETHEUS_CLUSTER_IP:$PROMETHEUS_PORT\"
}" 
