#!/bin/bash
# Fluent Bit Tests Runner
# 統一的測試運行腳本（適合 CI/CD）

set -e

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLUENT_BIT_DIR="$(dirname "$TESTS_DIR")"

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 檢查 Ruby 環境
if ! command -v ruby &> /dev/null; then
    echo -e "${RED}❌ 錯誤: 未找到 Ruby。請安裝 Ruby 2.7+${NC}"
    exit 1
fi

# 檢查 test-unit gem
if ! ruby -e "require 'test/unit'" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  警告: test-unit gem 未安裝，嘗試安裝...${NC}"
    gem install test-unit || {
        echo -e "${RED}❌ 錯誤: 無法安裝 test-unit gem${NC}"
        exit 1
    }
fi

echo "🧪 Fluent Bit 測試運行器"
echo ""

# 運行配置文件測試
echo -e "${GREEN}🔍 運行配置文件測試...${NC}"
cd "$TESTS_DIR"
if ruby test_fluent_bit_config.rb; then
    echo -e "${GREEN}✅ 配置文件測試通過${NC}"
else
    echo -e "${RED}❌ 配置文件測試失敗${NC}"
    exit 1
fi

echo ""

# 檢查服務是否運行（集成測試）
if docker ps | grep -q fluent-bit-sidecar; then
    echo -e "${GREEN}✅ Fluent Bit 服務正在運行${NC}"
    echo -e "${GREEN}🔗 運行集成測試...${NC}"
    if ruby test_fluent_bit_integration.rb; then
        echo -e "${GREEN}✅ 集成測試通過${NC}"
    else
        echo -e "${YELLOW}⚠️  集成測試失敗（可能是服務未正確配置）${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  Fluent Bit 服務未運行，跳過集成測試${NC}"
    echo "   要運行集成測試，請先啟動服務："
    echo "   cd $FLUENT_BIT_DIR/../.. && docker-compose -f docker-compose-fluentd-3.yaml up -d fluent-bit-sidecar"
fi

echo ""
echo -e "${GREEN}✅ 所有測試完成${NC}"
