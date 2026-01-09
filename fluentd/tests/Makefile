# Fluentd ETL Tests Makefile
# 支持分層測試結構，便於擴展多個微服務

.PHONY: test
test: test-syntax test-unit test-integration
	@echo "✅ 所有測試完成"

.PHONY: test-syntax
test-syntax:
	@echo "運行配置語法驗證..."
	@docker run --rm \
		-v "$(shell pwd)/..:/workspace/fluentd" \
		-w /workspace/fluentd/tests \
		ruby:3.2-slim \
		bash -c "apt-get update -qq > /dev/null 2>&1 && apt-get install -y -qq build-essential > /dev/null 2>&1 && gem install bundler > /dev/null 2>&1 && bundle install > /dev/null 2>&1 && ruby test_config_syntax.rb"

.PHONY: test-unit
test-unit:
	@echo "運行單元測試（通用 Filter 邏輯）..."
	@find unit -name "test_*.rb" -type f | while read test_file; do \
		echo "  - $$test_file"; \
		docker run --rm \
			-v "$(shell pwd)/..:/workspace/fluentd" \
			-w /workspace/fluentd/tests \
			ruby:3.2-slim \
			bash -c "apt-get update -qq > /dev/null 2>&1 && apt-get install -y -qq build-essential > /dev/null 2>&1 && gem install bundler > /dev/null 2>&1 && bundle install > /dev/null 2>&1 && ruby $$test_file" || exit 1; \
	done

.PHONY: test-integration
test-integration:
	@echo "運行整合測試（微服務 ETL）..."
	@find integration/services -name "test_*_etl.rb" -type f | while read test_file; do \
		echo "  - $$test_file"; \
		docker run --rm \
			-v "$(shell pwd)/..:/workspace/fluentd" \
			-w /workspace/fluentd/tests \
			ruby:3.2-slim \
			bash -c "apt-get update -qq > /dev/null 2>&1 && apt-get install -y -qq build-essential > /dev/null 2>&1 && gem install bundler > /dev/null 2>&1 && bundle install > /dev/null 2>&1 && ruby $$test_file" || exit 1; \
	done

.PHONY: test-fastapi
test-fastapi:
	@echo "運行 FastAPI App ETL 測試..."
	@docker run --rm \
		-v "$(shell pwd)/..:/workspace/fluentd" \
		-w /workspace/fluentd/tests \
		ruby:3.2-slim \
		bash -c "apt-get update -qq > /dev/null 2>&1 && apt-get install -y -qq build-essential > /dev/null 2>&1 && gem install bundler > /dev/null 2>&1 && bundle install > /dev/null 2>&1 && ruby integration/services/fastapi_app/test_fastapi_app_etl.rb"

.PHONY: install-deps
install-deps:
	@echo "安裝測試依賴..."
	@bundle install

.PHONY: clean
clean:
	@echo "清理測試產物..."
	@rm -f *.log
	@rm -rf .bundle
	@rm -rf vendor
