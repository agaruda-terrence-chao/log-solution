#!/bin/bash
# Fluentd ETL Logic Test Script
# 運行分層測試：語法驗證、單元測試、整合測試

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLUENTD_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TESTS_DIR="$SCRIPT_DIR"

echo "======================================"
echo "Fluentd ETL Logic Tests"
echo "======================================"
echo ""
echo "測試目錄: $TESTS_DIR"
echo "配置文件: $FLUENTD_DIR/conf2/fluent.conf"
echo ""

cd "$TESTS_DIR"

# 检查 Docker 是否可用
if command -v docker &> /dev/null; then
    USE_DOCKER=true
else
    USE_DOCKER=false
    if ! command -v bundle &> /dev/null; then
        echo "錯誤: 需要安裝 bundler 或 Docker"
        exit 1
    fi
    bundle install > /dev/null 2>&1
fi

# 运行测试的函数
run_test() {
    local test_file=$1
    local test_name=$2
    
    echo "--------------------------------------"
    echo "測試: $test_name"
    echo "文件: $test_file"
    echo "--------------------------------------"
    
    if [ "$USE_DOCKER" = true ]; then
        docker run --rm \
            -v "$FLUENTD_DIR:/workspace/fluentd" \
            -w /workspace/fluentd/tests \
            ruby:3.2-slim \
            bash -c "apt-get update -qq > /dev/null 2>&1 && apt-get install -y -qq build-essential > /dev/null 2>&1 && gem install bundler > /dev/null 2>&1 && bundle install > /dev/null 2>&1 && ruby $test_file"
    else
        ruby "$test_file"
    fi
    
    if [ $? -eq 0 ]; then
        echo "✅ $test_name 通過"
        echo ""
        return 0
    else
        echo "❌ $test_name 失敗"
        echo ""
        return 1
    fi
}

# 运行测试目录的函数
run_test_dir() {
    local test_dir=$1
    local test_name=$2
    
    echo "--------------------------------------"
    echo "測試: $test_name"
    echo "目錄: $test_dir"
    echo "--------------------------------------"
    
    local failed=0
    local total=0
    
    while IFS= read -r test_file; do
        total=$((total + 1))
        echo "  - $test_file"
        
        if [ "$USE_DOCKER" = true ]; then
            docker run --rm \
                -v "$FLUENTD_DIR:/workspace/fluentd" \
                -w /workspace/fluentd/tests \
                ruby:3.2-slim \
                bash -c "apt-get update -qq > /dev/null 2>&1 && apt-get install -y -qq build-essential > /dev/null 2>&1 && gem install bundler > /dev/null 2>&1 && bundle install > /dev/null 2>&1 && ruby $test_file" || failed=$((failed + 1))
        else
            ruby "$test_file" || failed=$((failed + 1))
        fi
    done < <(find "$test_dir" -name "test_*.rb" -type f)
    
    if [ $failed -eq 0 ]; then
        echo "✅ $test_name 通過 ($total 個測試文件)"
        echo ""
        return 0
    else
        echo "❌ $test_name 失敗 ($failed/$total 個測試文件失敗)"
        echo ""
        return 1
    fi
}

# 运行所有测试
FAILED_TESTS=0

# Test 1: 配置语法验证
run_test "test_config_syntax.rb" "配置語法驗證" || FAILED_TESTS=$((FAILED_TESTS + 1))

# Test 2: 單元測試 - 通用 Filter 邏輯
run_test_dir "unit" "單元測試（通用 Filter 邏輯）" || FAILED_TESTS=$((FAILED_TESTS + 1))

# Test 3: 整合測試 - 微服務 ETL
run_test_dir "integration/services" "整合測試（微服務 ETL）" || FAILED_TESTS=$((FAILED_TESTS + 1))

# 总结
echo "======================================"
if [ $FAILED_TESTS -eq 0 ]; then
    echo "✅ 所有測試通過！"
    echo "配置文件已驗證，ETL 邏輯正確"
    exit 0
else
    echo "❌ 有 $FAILED_TESTS 個測試類別失敗"
    echo "請檢查測試結果並修復問題"
    exit 1
fi
