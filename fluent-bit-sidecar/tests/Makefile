# Fluent Bit Tests Makefile
# 支持配置文件测试和集成测试

# 工作目录
TESTS_DIR := $(shell pwd)
FLUENT_BIT_DIR := $(shell dirname $(TESTS_DIR))

# Fluent Bit 可执行文件路径（可通过环境变量覆盖）
FLUENT_BIT_BIN ?= fluent-bit

# 检查 Fluent Bit 是否可用
HAS_FLUENT_BIT := $(shell command -v $(FLUENT_BIT_BIN) 2> /dev/null || docker exec log-solution-fluentd-3-fluent-bit-sidecar test -f /fluent-bit/bin/fluent-bit 2> /dev/null)

.PHONY: all
all: test

# ============================================================
# 测试目标
# ============================================================

.PHONY: test
test: test-config test-integration
	@echo "✅ 所有測試完成"

.PHONY: test-config
test-config:
	@echo "🔍 運行 Fluent Bit 配置文件測試..."
	@if [ -z "$(HAS_FLUENT_BIT)" ]; then \
		echo "⚠️  警告: fluent-bit 命令不可用，部分測試將被跳過"; \
		echo "   可以通過環境變量 FLUENT_BIT_BIN 指定路徑，或使用 Docker 環境"; \
	fi
	@cd $(TESTS_DIR) && ruby test_fluent_bit_config.rb

.PHONY: test-integration
test-integration:
	@echo "🔗 運行 Fluent Bit 集成測試..."
	@echo "⚠️  注意: 集成測試需要 Fluent Bit 服務運行在 localhost:8888 和 localhost:8889"
	@cd $(TESTS_DIR) && ruby test_fluent_bit_integration.rb

# ============================================================
# 辅助命令
# ============================================================

.PHONY: check-service
check-service:
	@echo "🔍 檢查 Fluent Bit 服務狀態..."
	@if docker ps | grep -q fluent-bit-sidecar; then \
		echo "✅ Fluent Bit 服務正在運行"; \
		docker ps --filter "name=fluent-bit-sidecar" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"; \
	else \
		echo "❌ Fluent Bit 服務未運行"; \
		echo "   請運行: cd ../.. && docker-compose -f docker-compose-fluentd-3.yaml up -d fluent-bit-sidecar"; \
	fi

.PHONY: start-service
start-service:
	@echo "🚀 啟動 Fluent Bit 服務..."
	@cd $(FLUENT_BIT_DIR)/../.. && docker-compose -f docker-compose-fluentd-3.yaml up -d fluent-bit-sidecar
	@echo "⏳ 等待服務啟動..."
	@sleep 3
	@$(MAKE) check-service

.PHONY: help
help:
	@echo "Fluent Bit Tests Makefile"
	@echo ""
	@echo "測試命令:"
	@echo "  make test              - 運行所有測試"
	@echo "  make test-config       - 運行配置文件測試"
	@echo "  make test-integration  - 運行集成測試"
	@echo ""
	@echo "服務管理:"
	@echo "  make check-service     - 檢查 Fluent Bit 服務狀態"
	@echo "  make start-service     - 啟動 Fluent Bit 服務"
	@echo ""
	@echo "環境變量:"
	@echo "  FLUENT_BIT_BIN        - Fluent Bit 可執行文件路徑（默認: fluent-bit）"
	@echo ""
	@echo "示例:"
	@echo "  make test                      # 運行所有測試"
	@echo "  make start-service && make test-integration  # 啟動服務後運行集成測試"
	@echo "  FLUENT_BIT_BIN=/path/to/fluent-bit make test-config  # 指定 Fluent Bit 路徑"
