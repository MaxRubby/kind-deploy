#!/bin/bash

# 应用配置
echo "创建 ServiceAccount 和 Token..."
kubectl apply -f all-rbac.yaml

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

echo "Token 获取成功："
echo "$TOKEN"

# 获取API服务器地址
API_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
echo -e "\nAPI Server 地址："
echo "$API_SERVER"

# 获取 Prometheus 服务信息
echo -e "\n获取 Prometheus 信息..."
PROMETHEUS_PORT=$(kubectl get svc prometheus-server -o jsonpath='{.spec.ports[0].port}')
PROMETHEUS_NODE_PORT=$(kubectl get svc prometheus-server -o jsonpath='{.spec.ports[0].nodePort}')
PROMETHEUS_CLUSTER_IP=$(kubectl get svc prometheus-server -o jsonpath='{.spec.clusterIP}')

echo "Prometheus 集群内访问地址: http://$PROMETHEUS_CLUSTER_IP:$PROMETHEUS_PORT"
if [ ! -z "$PROMETHEUS_NODE_PORT" ]; then
    echo "Prometheus NodePort 访问地址: http://$(echo $API_SERVER | sed 's|https://\(.*\):[0-9]*|\1|'):$PROMETHEUS_NODE_PORT"
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
