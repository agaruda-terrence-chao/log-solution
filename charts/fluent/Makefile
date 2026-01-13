# Helm Charts Makefile
# 用于部署和管理统一的 Fluent 日志收集链路

NAMESPACE ?= fluent
RELEASE_NAME ?= fluent

# OpenSearch 配置（根据实际环境调整）
OPENSEARCH_SERVICE ?= opensearch-cluster-master
OPENSEARCH_NAMESPACE ?= opensearch

.PHONY: help
help:
	@echo "统一的 Fluent 日志收集链路 Helm Chart"
	@echo ""
	@echo "部署命令:"
	@echo "  make install               - 部署 Fluent 栈（fluent-bit + fluentd）"
	@echo ""
	@echo "升级命令:"
	@echo "  make upgrade               - 升级 Fluent 栈"
	@echo ""
	@echo "卸载命令:"
	@echo "  make uninstall             - 卸载 Fluent 栈"
	@echo ""
	@echo "验证命令:"
	@echo "  make status                - 查看所有组件状态"
	@echo "  make test-connection      - 测试组件连接"
	@echo "  make lint                  - 检查 Helm Chart 语法"
	@echo "  make template              - 生成 Kubernetes 清单"
	@echo ""
	@echo "环境变量:"
	@echo "  NAMESPACE                  - Kubernetes 命名空间（默认: fluent）"
	@echo "  RELEASE_NAME               - Helm Release 名称（默认: fluent）"
	@echo "  OPENSEARCH_SERVICE         - OpenSearch 服务名称（默认: opensearch-cluster-master）"
	@echo "  OPENSEARCH_NAMESPACE       - OpenSearch 命名空间（默认: opensearch）"

.PHONY: namespace
namespace:
	@echo "创建命名空间: $(NAMESPACE)"
	@kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -

# ============================================================
# 部署命令
# ============================================================

.PHONY: install
install: namespace
	@echo "🚀 部署统一的 Fluent 栈（fluent-bit + fluentd）..."
	@helm install $(RELEASE_NAME) . \
		--namespace $(NAMESPACE) \
		--set fluentd.opensearch.service.name=$(OPENSEARCH_SERVICE) \
		--set fluentd.opensearch.service.namespace=$(OPENSEARCH_NAMESPACE) \
		--set fluentd.opensearch.useService=true \
		--set fluentd.opensearch.scheme=http \
		--set fluentd.opensearch.verifySsl=false
	@echo "⏳ 等待 Fluent Bit 就绪..."
	@kubectl wait --for=condition=ready pod \
		-l app.kubernetes.io/component=fluent-bit \
		-n $(NAMESPACE) \
		--timeout=300s || true
	@echo "⏳ 等待 Fluentd 就绪..."
	@kubectl wait --for=condition=ready pod \
		-l app.kubernetes.io/component=fluentd \
		-n $(NAMESPACE) \
		--timeout=300s || true
	@echo "✅ Fluent 栈部署完成"

# ============================================================
# 升级命令
# ============================================================

.PHONY: upgrade
upgrade:
	@echo "🔄 升级 Fluent 栈..."
	@helm upgrade $(RELEASE_NAME) . \
		--namespace $(NAMESPACE) \
		--set fluentd.opensearch.service.name=$(OPENSEARCH_SERVICE) \
		--set fluentd.opensearch.service.namespace=$(OPENSEARCH_NAMESPACE) \
		--set fluentd.opensearch.useService=true \
		--set fluentd.opensearch.scheme=http \
		--set fluentd.opensearch.verifySsl=false
	@echo "✅ Fluent 栈升级完成"

# ============================================================
# 卸载命令
# ============================================================

.PHONY: uninstall
uninstall:
	@echo "🗑️  卸载 Fluent 栈..."
	@helm uninstall $(RELEASE_NAME) --namespace $(NAMESPACE) || true
	@echo "✅ Fluent 栈卸载完成"

# ============================================================
# 验证命令
# ============================================================

.PHONY: status
status:
	@echo "📊 Fluent 栈状态:"
	@echo ""
	@echo "=== Fluent Bit ==="
	@kubectl get pods,svc -n $(NAMESPACE) -l app.kubernetes.io/component=fluent-bit || true
	@echo ""
	@echo "=== Fluentd ==="
	@kubectl get pods,svc -n $(NAMESPACE) -l app.kubernetes.io/component=fluentd || true

.PHONY: test-connection
test-connection:
	@echo "🔍 测试组件连接..."
	@echo ""
	@echo "1. 测试 Fluent Bit -> Fluentd 连接:"
	@kubectl run -it --rm test-connection-$$(date +%s) \
		--image=curlimages/curl:latest \
		--restart=Never \
		-n $(NAMESPACE) -- \
		curl -X POST http://$(RELEASE_NAME)-fluent-bit.$(NAMESPACE).svc.cluster.local:8888 \
		-H "Content-Type: application/json" \
		-d '{"message":"[ORDER] Connection test","level":"INFO","order_id":"TEST-001"}' || true
	@echo ""
	@echo "2. 检查 Fluentd 日志:"
	@kubectl logs -n $(NAMESPACE) -l app.kubernetes.io/component=fluentd --tail=10 || true

.PHONY: lint
lint:
	@echo "🔍 检查 Helm Chart 语法..."
	@helm lint . || echo "⚠️  fluent lint 失败（可能需要安装 helm）"

.PHONY: template
template:
	@echo "📄 生成 Kubernetes 清单:"
	@helm template $(RELEASE_NAME) . \
		--set fluentd.opensearch.service.name=$(OPENSEARCH_SERVICE) \
		--set fluentd.opensearch.service.namespace=$(OPENSEARCH_NAMESPACE) \
		--set fluentd.opensearch.useService=true \
		--set fluentd.opensearch.scheme=http \
		--set fluentd.opensearch.verifySsl=false || echo "需要安装 helm"
