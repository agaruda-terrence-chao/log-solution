# Fluentd ETL Tests Makefile
# 支持分層測試結構，便於擴展多個微服務
# 使用预构建的 Docker 镜像加速测试执行

# Docker 镜像名称和标签
DOCKER_IMAGE = fluentd-test-env
DOCKER_TAG = latest
DOCKER_FULL_IMAGE = $(DOCKER_IMAGE):$(DOCKER_TAG)

# 工作目录
TESTS_DIR := $(shell pwd)
FLUENTD_DIR := $(shell dirname $(TESTS_DIR))

# 检查是否使用 Docker（如果本地有 Ruby 环境，可以设置 USE_LOCAL=true）
USE_LOCAL ?= false

# 检查本地 Ruby 环境
HAS_RUBY := $(shell command -v ruby 2> /dev/null)
HAS_BUNDLER := $(shell command -v bundle 2> /dev/null)

# Docker 运行命令（使用预构建镜像）
DOCKER_RUN = docker run --rm \
	-v "$(FLUENTD_DIR):/workspace/fluentd" \
	-w /workspace/fluentd/tests \
	$(DOCKER_FULL_IMAGE)


.PHONY: all
all: test

# ============================================================
# Docker 镜像构建
# ============================================================

.PHONY: build-image
build-image:
	@echo "🔨 構建測試環境 Docker 鏡像..."
	@cd $(TESTS_DIR) && docker build -t $(DOCKER_FULL_IMAGE) -f Dockerfile .
	@echo "✅ 鏡像構建完成: $(DOCKER_FULL_IMAGE)"

.PHONY: image-exists
image-exists:
	@docker image inspect $(DOCKER_FULL_IMAGE) > /dev/null 2>&1 || \
		($(MAKE) build-image)

# ============================================================
# 本地环境检查
# ============================================================

.PHONY: check-local
check-local:
	@if [ "$(USE_LOCAL)" = "true" ]; then \
		if [ -z "$(HAS_RUBY)" ]; then \
			echo "❌ 錯誤: 未找到 Ruby。請安裝 Ruby 或使用 Docker (USE_LOCAL=false)"; \
			exit 1; \
		fi; \
		if [ -z "$(HAS_BUNDLER)" ]; then \
			echo "❌ 錯誤: 未找到 bundler。請運行 'gem install bundler' 或使用 Docker (USE_LOCAL=false)"; \
			exit 1; \
		fi; \
		if [ ! -f Gemfile.lock ] || [ Gemfile -nt Gemfile.lock ]; then \
			echo "📦 安裝依賴..." && bundle install; \
		fi; \
	fi

# ============================================================
# 测试目标
# ============================================================

.PHONY: test
test: test-syntax test-unit test-integration
	@echo "✅ 所有測試完成"

.PHONY: test-syntax
test-syntax: check-local
	@echo "🔍 運行配置語法驗證..."
	@if [ "$(USE_LOCAL)" = "true" ]; then \
		bundle exec ruby test_config_syntax.rb; \
	else \
		$(MAKE) image-exists > /dev/null 2>&1; \
		$(DOCKER_RUN) ruby test_config_syntax.rb; \
	fi

.PHONY: test-unit
test-unit: check-local
	@echo "🧪 運行單元測試（通用 Filter 邏輯）..."
	@find unit -name "test_*.rb" -type f | while read test_file; do \
		echo "  - $$test_file"; \
		if [ "$(USE_LOCAL)" = "true" ]; then \
			bundle exec ruby "$$test_file" || exit 1; \
		else \
			$(MAKE) image-exists > /dev/null 2>&1; \
			$(DOCKER_RUN) ruby "$$test_file" || exit 1; \
		fi; \
	done

.PHONY: test-integration
test-integration: check-local
	@echo "🔗 運行整合測試（微服務 ETL）..."
	@find integration/services -name "test_*_etl.rb" -type f | while read test_file; do \
		echo "  - $$test_file"; \
		if [ "$(USE_LOCAL)" = "true" ]; then \
			bundle exec ruby "$$test_file" || exit 1; \
		else \
			$(MAKE) image-exists > /dev/null 2>&1; \
			$(DOCKER_RUN) ruby "$$test_file" || exit 1; \
		fi; \
	done

.PHONY: test-fastapi
test-fastapi: check-local
	@echo "🚀 運行 FastAPI App ETL 測試..."
	@if [ "$(USE_LOCAL)" = "true" ]; then \
		bundle exec ruby integration/services/fastapi_app/test_fastapi_app_etl.rb; \
	else \
		$(MAKE) image-exists > /dev/null 2>&1; \
		$(DOCKER_RUN) ruby integration/services/fastapi_app/test_fastapi_app_etl.rb; \
	fi

.PHONY: test-order-app
test-order-app: check-local
	@echo "📦 運行 Order App ETL 測試..."
	@if [ "$(USE_LOCAL)" = "true" ]; then \
		bundle exec ruby integration/services/order_app/test_order_app_etl.rb; \
	else \
		$(MAKE) image-exists > /dev/null 2>&1; \
		$(DOCKER_RUN) ruby integration/services/order_app/test_order_app_etl.rb; \
	fi

.PHONY: test-user-app
test-user-app: check-local
	@echo "👤 運行 User App ETL 測試..."
	@if [ "$(USE_LOCAL)" = "true" ]; then \
		bundle exec ruby integration/services/user_app/test_user_app_etl.rb; \
	else \
		$(MAKE) image-exists > /dev/null 2>&1; \
		$(DOCKER_RUN) ruby integration/services/user_app/test_user_app_etl.rb; \
	fi

# ============================================================
# 辅助命令
# ============================================================

.PHONY: install-deps
install-deps:
	@echo "📦 安裝測試依賴..."
	@if [ "$(USE_LOCAL)" = "true" ]; then \
		bundle install; \
	else \
		$(MAKE) build-image; \
	fi

.PHONY: clean
clean:
	@echo "🧹 清理測試產物..."
	@rm -f *.log
	@rm -rf .bundle
	@rm -rf vendor
	@rm -f Gemfile.lock

.PHONY: clean-image
clean-image:
	@echo "🧹 清理 Docker 鏡像..."
	@docker rmi $(DOCKER_FULL_IMAGE) 2>/dev/null || true

.PHONY: clean-all
clean-all: clean clean-image

.PHONY: help
help:
	@echo "Fluentd ETL Tests Makefile"
	@echo ""
	@echo "測試命令:"
	@echo "  make test              - 運行所有測試"
	@echo "  make test-syntax       - 運行配置語法驗證"
	@echo "  make test-unit         - 運行單元測試"
	@echo "  make test-integration  - 運行整合測試"
	@echo "  make test-fastapi      - 運行 FastAPI 測試"
	@echo "  make test-order-app    - 運行 Order App 測試"
	@echo "  make test-user-app     - 運行 User App 測試"
	@echo ""
	@echo "構建命令:"
	@echo "  make build-image       - 構建測試環境 Docker 鏡像"
	@echo "  make install-deps      - 安裝測試依賴"
	@echo ""
	@echo "清理命令:"
	@echo "  make clean             - 清理測試產物"
	@echo "  make clean-image       - 清理 Docker 鏡像"
	@echo "  make clean-all         - 清理所有（產物 + 鏡像）"
	@echo ""
	@echo "環境選項:"
	@echo "  USE_LOCAL=true         - 使用本地 Ruby 環境（需要安裝 Ruby 和 bundler）"
	@echo "  USE_LOCAL=false        - 使用 Docker（默認）"
	@echo ""
	@echo "示例:"
	@echo "  make test                      # 使用 Docker 運行所有測試"
	@echo "  USE_LOCAL=true make test       # 使用本地環境運行所有測試"
	@echo "  make build-image && make test  # 構建鏡像後運行測試"
