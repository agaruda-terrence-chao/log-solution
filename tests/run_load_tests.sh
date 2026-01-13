#!/bin/bash
# 运行 Order App 和 User App 压力测试的便捷脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查 k6 是否安装
if ! command -v k6 &> /dev/null; then
    echo -e "${RED}❌ 错误: 未找到 k6。请安装 k6:${NC}"
    echo "   macOS: brew install k6"
    echo "   或参考 README_K6.md"
    exit 1
fi

# 检查服务是否运行
check_service() {
    local port=$1
    local service=$2
    
    if ! curl -s "http://localhost:${port}" > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  警告: ${service} 服务可能未运行 (端口 ${port})${NC}"
        echo "   请运行: cd ../.. && docker-compose -f docker-compose-fluentd-3.yaml up -d fluent-bit-sidecar"
        return 1
    fi
    return 0
}

# 显示菜单
show_menu() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  K6 压力测试脚本${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo "1. 运行 Order App 压力测试"
    echo "2. 运行 User App 压力测试"
    echo "3. 同时运行两个服务的压力测试（后台）"
    echo "4. 快速测试（10秒，低 QPS）"
    echo "5. 退出"
    echo ""
}

# 运行 Order App 测试
run_order_app_test() {
    echo -e "${GREEN}🚀 运行 Order App 压力测试...${NC}"
    check_service 8888 "Order App (Fluent Bit HTTP input)" || return 1
    k6 run load_test_order_app.js
}

# 运行 User App 测试
run_user_app_test() {
    echo -e "${GREEN}🚀 运行 User App 压力测试...${NC}"
    check_service 8889 "User App (Fluent Bit HTTP input)" || return 1
    k6 run load_test_user_app.js
}

# 快速测试（低 QPS，短时间）
run_quick_test() {
    echo -e "${GREEN}⚡ 运行快速测试（10秒，QPS=100）...${NC}"
    echo ""
    echo -e "${YELLOW}Order App 快速测试:${NC}"
    k6 run --duration 10s -e TARGET_QPS=100 load_test_order_app.js 2>&1 | grep -E "(http_reqs|errors|http_req_duration)" || true
    echo ""
    echo -e "${YELLOW}User App 快速测试:${NC}"
    k6 run --duration 10s -e TARGET_QPS=100 load_test_user_app.js 2>&1 | grep -E "(http_reqs|errors|http_req_duration)" || true
}

# 主循环
if [ $# -eq 0 ]; then
    # 交互式菜单
    while true; do
        show_menu
        read -p "请选择 (1-5): " choice
        case $choice in
            1)
                run_order_app_test
                ;;
            2)
                run_user_app_test
                ;;
            3)
                echo -e "${GREEN}🚀 同时运行两个服务的压力测试...${NC}"
                check_service 8888 "Order App" || continue
                check_service 8889 "User App" || continue
                k6 run load_test_order_app.js &
                ORDER_PID=$!
                k6 run load_test_user_app.js &
                USER_PID=$!
                echo "Order App 测试 PID: $ORDER_PID"
                echo "User App 测试 PID: $USER_PID"
                echo "按 Ctrl+C 停止测试"
                wait $ORDER_PID $USER_PID
                ;;
            4)
                run_quick_test
                ;;
            5)
                echo "退出"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                ;;
        esac
        echo ""
        read -p "按 Enter 继续..."
    done
else
    # 命令行参数模式
    case $1 in
        order)
            run_order_app_test
            ;;
        user)
            run_user_app_test
            ;;
        both)
            check_service 8888 "Order App" || exit 1
            check_service 8889 "User App" || exit 1
            k6 run load_test_order_app.js &
            ORDER_PID=$!
            k6 run load_test_user_app.js &
            USER_PID=$!
            wait $ORDER_PID $USER_PID
            ;;
        quick)
            run_quick_test
            ;;
        *)
            echo "用法: $0 [order|user|both|quick]"
            echo ""
            echo "   order  - 运行 Order App 压力测试"
            echo "   user   - 运行 User App 压力测试"
            echo "   both   - 同时运行两个服务的压力测试"
            echo "   quick  - 快速测试（10秒，低 QPS）"
            exit 1
            ;;
    esac
fi
