#!/bin/bash
# Kubernetes 环境 K6 压力测试运行脚本（Port-Forward 方式）

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置（针对 port-forward 优化）
NAMESPACE="${NAMESPACE:-fluent}"
FLUENT_BIT_SERVICE="${FLUENT_BIT_SERVICE:-localhost}"
OPENSEARCH_SERVICE="${OPENSEARCH_SERVICE:-localhost}"
TARGET_QPS="${TARGET_QPS:-1000}"
DURATION="${DURATION:-3s}"
TEST_TYPE="${1:-order}"  # order 或 user

# 检查参数
if [ "$TEST_TYPE" != "order" ] && [ "$TEST_TYPE" != "user" ]; then
  echo -e "${RED}错误: 测试类型必须是 'order' 或 'user'${NC}"
  echo "用法: $0 [order|user]"
  exit 1
fi

# 设置端口
if [ "$TEST_TYPE" == "order" ]; then
  PORT="8888"
  TEST_SCRIPT="load_test_order_app_k8s.js"
  SERVICE_NAME="order-app"
else
  PORT="8889"
  TEST_SCRIPT="load_test_user_app_k8s.js"
  SERVICE_NAME="user-app"
fi

# 转换为大写（兼容旧版 bash）
TEST_TYPE_UPPER=$(echo "$TEST_TYPE" | tr '[:lower:]' '[:upper:]')
echo -e "${GREEN}=== K6 压力测试 - ${TEST_TYPE_UPPER} App ===${NC}"
echo ""
echo "配置:"
echo "  Namespace: $NAMESPACE"
echo "  Fluent Bit Service: $FLUENT_BIT_SERVICE:$PORT"
echo "  OpenSearch Service: $OPENSEARCH_SERVICE:9200"
echo "  Target QPS: $TARGET_QPS"
echo "  Duration: $DURATION"
echo ""

# 检查 K6 是否安装
if ! command -v k6 &> /dev/null; then
  echo -e "${YELLOW}警告: K6 未安装，将使用 Kubernetes Pod 运行${NC}"
  USE_K8S_POD=true
else
  USE_K8S_POD=false
fi

# 检查 port-forward 是否已设置
echo -e "${BLUE}检查 port-forward 连接...${NC}"

check_port_forward() {
  local port=$1
  # 使用多种方式检查端口（兼容 macOS 和 Linux）
  if command -v nc >/dev/null 2>&1; then
    # 使用 nc (netcat)
    if nc -z localhost $port 2>/dev/null; then
      return 0
    fi
  elif command -v timeout >/dev/null 2>&1; then
    # 使用 timeout + bash tcp check
    if timeout 2 bash -c "echo > /dev/tcp/localhost/$port" 2>/dev/null; then
      return 0
    fi
  else
    # 使用 curl 检查（最兼容的方式）
    if curl -s --connect-timeout 1 http://localhost:$port >/dev/null 2>&1; then
      return 0
    fi
  fi
  return 1
}

if ! check_port_forward $PORT; then
  echo -e "${YELLOW}⚠️  端口 $PORT 不可访问${NC}"
  echo ""
  echo "请先设置 port-forward:"
  echo "  方式 1: 使用自动脚本"
  echo "    ./setup_port_forward.sh"
  echo ""
  echo "  方式 2: 手动设置"
  echo "    kubectl port-forward -n $NAMESPACE svc/fluent-fluent-bit $PORT:$PORT"
  echo ""
  read -p "按 Enter 继续（假设已设置 port-forward）..."
  
  # 再次检查
  if ! check_port_forward $PORT; then
    echo -e "${RED}错误: 端口 $PORT 仍然不可访问，请先设置 port-forward${NC}"
    exit 1
  fi
fi

echo -e "${GREEN}✓ Port-forward 连接正常 (localhost:$PORT)${NC}"
echo ""

# 运行测试
if [ "$USE_K8S_POD" = true ]; then
  echo -e "${GREEN}使用 Kubernetes Pod 运行测试...${NC}"
  
  # 创建临时 ConfigMap（如果不存在）
  if ! kubectl get configmap k6-${TEST_TYPE}-test-script -n $NAMESPACE &>/dev/null; then
    echo "创建 ConfigMap..."
    kubectl create configmap k6-${TEST_TYPE}-test-script \
      --from-file=${TEST_SCRIPT}=$(dirname "$0")/${TEST_SCRIPT} \
      -n $NAMESPACE
  fi
  
  # 运行 K6 Job
  JOB_NAME="k6-${TEST_TYPE}-test-$(date +%s)"
  
  kubectl run $JOB_NAME \
    --image=grafana/k6:latest \
    --restart=Never \
    -n $NAMESPACE \
    --rm -i \
    --env="FLUENT_BIT_SERVICE=$FLUENT_BIT_SERVICE" \
    --env="FLUENT_BIT_${TEST_TYPE_UPPER}_PORT=$PORT" \
    --env="OPENSEARCH_SERVICE=$OPENSEARCH_SERVICE" \
    --env="OPENSEARCH_PORT=9200" \
    --env="TARGET_QPS=$TARGET_QPS" \
    --env="DURATION=$DURATION" \
    -- k6 run - <(kubectl get configmap k6-${TEST_TYPE}-test-script -n $NAMESPACE -o jsonpath="{.data.${TEST_SCRIPT}}")
else
  echo -e "${GREEN}使用本地 K6 运行测试...${NC}"
  
  # 设置环境变量
  export FLUENT_BIT_SERVICE="${FLUENT_BIT_SERVICE:-localhost}"
  # 动态设置端口环境变量（兼容旧版 bash）
  if [ "$TEST_TYPE" == "order" ]; then
    export FLUENT_BIT_ORDER_PORT=$PORT
  else
    export FLUENT_BIT_USER_PORT=$PORT
  fi
  export OPENSEARCH_SERVICE="${OPENSEARCH_SERVICE:-localhost}"
  export OPENSEARCH_PORT=9200
  export TARGET_QPS=$TARGET_QPS
  export DURATION=$DURATION
  
  # 运行 K6
  k6 run "$(dirname "$0")/${TEST_SCRIPT}"
fi

echo ""
echo -e "${GREEN}测试完成！${NC}"
