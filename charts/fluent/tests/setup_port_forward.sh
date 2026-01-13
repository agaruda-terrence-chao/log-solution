#!/bin/bash
# Port Forward 设置脚本
# 用于在本地设置 Kubernetes Service 的端口转发，以便进行压力测试

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
NAMESPACE="${NAMESPACE:-fluent}"
SERVICE_NAME="${SERVICE_NAME:-fluent-fluent-bit}"
ORDER_PORT="${ORDER_PORT:-8888}"
USER_PORT="${USER_PORT:-8889}"
OPENSEARCH_NAMESPACE="${OPENSEARCH_NAMESPACE:-opensearch}"
OPENSEARCH_SERVICE="${OPENSEARCH_SERVICE:-opensearch-cluster-master}"
OPENSEARCH_PORT="${OPENSEARCH_PORT:-9200}"

echo -e "${GREEN}=== Port Forward 设置脚本 ===${NC}"
echo ""
echo "配置:"
echo "  Namespace: $NAMESPACE"
echo "  Service: $SERVICE_NAME"
echo "  Order App Port: $ORDER_PORT"
echo "  User App Port: $USER_PORT"
echo "  OpenSearch Namespace: $OPENSEARCH_NAMESPACE"
echo "  OpenSearch Service: $OPENSEARCH_SERVICE"
echo "  OpenSearch Port: $OPENSEARCH_PORT"
echo ""

# 检查 Service 是否存在
if ! kubectl get svc -n $NAMESPACE $SERVICE_NAME &>/dev/null; then
  echo -e "${RED}错误: Service $SERVICE_NAME 在 namespace $NAMESPACE 中不存在${NC}"
  exit 1
fi

# 检查端口是否已被占用
check_port() {
  local port=$1
  if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    echo -e "${YELLOW}警告: 端口 $port 已被占用${NC}"
    return 1
  fi
  return 0
}

# 设置 port-forward 的函数
setup_port_forward() {
  local port=$1
  local target_port=$2
  local name=$3
  
  if check_port $port; then
    echo -e "${GREEN}设置 $name port-forward: $port -> $target_port${NC}"
    kubectl port-forward -n $NAMESPACE svc/$SERVICE_NAME $port:$target_port > /dev/null 2>&1 &
    local pid=$!
    sleep 1
    if kill -0 $pid 2>/dev/null; then
      echo $pid > /tmp/k6-port-forward-$port.pid
      echo -e "${GREEN}  ✓ $name port-forward 已启动 (PID: $pid)${NC}"
      return 0
    else
      echo -e "${RED}  ✗ $name port-forward 启动失败${NC}"
      return 1
    fi
  else
    echo -e "${YELLOW}  跳过 $name port-forward (端口已被占用)${NC}"
    return 0
  fi
}

# 设置所有 port-forward
echo -e "${BLUE}开始设置 port-forward...${NC}"
echo ""

# Order App port-forward
setup_port_forward $ORDER_PORT $ORDER_PORT "Order App"

# User App port-forward
setup_port_forward $USER_PORT $USER_PORT "User App"

# OpenSearch port-forward (可选)
if [ "${SETUP_OPENSEARCH:-true}" = "true" ]; then
  if check_port $OPENSEARCH_PORT; then
    echo -e "${GREEN}设置 OpenSearch port-forward: $OPENSEARCH_PORT -> $OPENSEARCH_PORT${NC}"
    kubectl port-forward -n $OPENSEARCH_NAMESPACE svc/$OPENSEARCH_SERVICE $OPENSEARCH_PORT:$OPENSEARCH_PORT > /dev/null 2>&1 &
    OPENSEARCH_PID=$!
    sleep 1
    if kill -0 $OPENSEARCH_PID 2>/dev/null; then
      echo $OPENSEARCH_PID > /tmp/k6-port-forward-opensearch.pid
      echo -e "${GREEN}  ✓ OpenSearch port-forward 已启动 (PID: $OPENSEARCH_PID)${NC}"
    else
      echo -e "${YELLOW}  ⚠ OpenSearch port-forward 启动失败（可选）${NC}"
    fi
  else
    echo -e "${YELLOW}  跳过 OpenSearch port-forward (端口已被占用)${NC}"
  fi
fi

echo ""
echo -e "${GREEN}=== Port Forward 设置完成 ===${NC}"
echo ""
echo "已启动的 port-forward:"
echo "  - Order App:  http://localhost:$ORDER_PORT"
echo "  - User App:   http://localhost:$USER_PORT"
if [ -f /tmp/k6-port-forward-opensearch.pid ]; then
  echo "  - OpenSearch: http://localhost:$OPENSEARCH_PORT"
fi
echo ""
echo -e "${YELLOW}提示:${NC}"
echo "  - 这些 port-forward 进程将在后台运行"
echo "  - 要停止所有 port-forward，运行: ./cleanup_port_forward.sh"
echo "  - 或手动停止: kill \$(cat /tmp/k6-port-forward-*.pid)"
echo ""
