#!/bin/bash
# 清理 Port Forward 进程

set -e

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== 清理 Port Forward 进程 ===${NC}"
echo ""

# 查找并停止所有 port-forward 进程
FOUND_PID_FILES=false
for pidfile in /tmp/k6-port-forward-*.pid; do
  if [ -f "$pidfile" ]; then
    FOUND_PID_FILES=true
    pid=$(cat "$pidfile")
    if kill -0 $pid 2>/dev/null; then
      kill $pid
      echo "已停止进程 (PID: $pid)"
      rm -f "$pidfile"
    else
      echo "进程已不存在 (PID: $pid)"
      rm -f "$pidfile"
    fi
  fi
done

if [ "$FOUND_PID_FILES" = false ]; then
  echo -e "${YELLOW}未找到 port-forward PID 文件${NC}"
fi

# 也尝试通过 kubectl 查找并停止
kubectl_pids=$(ps aux | grep "kubectl port-forward" | grep -v grep | awk '{print $2}' || true)
if [ -n "$kubectl_pids" ]; then
  echo "发现 kubectl port-forward 进程，正在停止..."
  echo "$kubectl_pids" | xargs kill 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}清理完成${NC}"
