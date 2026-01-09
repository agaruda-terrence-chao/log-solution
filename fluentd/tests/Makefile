# Fluentd ETL Tests Makefile
# 简化的测试命令

.PHONY: test
test:
	@echo "运行所有测试..."
	@chmod +x test.sh
	@./test.sh

.PHONY: test-etl
test-etl:
	@echo "运行 ETL 逻辑测试..."
	@docker run --rm \
		-v "$(shell pwd)/..:/workspace/fluentd" \
		-w /workspace/fluentd/tests \
		ruby:3.2-slim \
		bash -c "apt-get update -qq > /dev/null 2>&1 && \
		apt-get install -y -qq build-essential > /dev/null 2>&1 && \
		gem install bundler > /dev/null 2>&1 && \
		bundle install > /dev/null 2>&1 && \
		ruby test_etl_logic.rb"

.PHONY: test-syntax
test-syntax:
	@echo "运行配置语法验证..."
	@docker run --rm \
		-v "$(shell pwd)/..:/workspace/fluentd" \
		-w /workspace/fluentd/tests \
		ruby:3.2-slim \
		bash -c "apt-get update -qq > /dev/null 2>&1 && \
		apt-get install -y -qq build-essential > /dev/null 2>&1 && \
		gem install bundler > /dev/null 2>&1 && \
		bundle install > /dev/null 2>&1 && \
		ruby test_config_syntax.rb"

.PHONY: install-deps
install-deps:
	@echo "安装测试依赖..."
	@bundle install

.PHONY: clean
clean:
	@echo "清理测试产物..."
	@rm -f *.log
	@rm -rf .bundle
	@rm -rf vendor
