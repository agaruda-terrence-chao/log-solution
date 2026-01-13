# Fluent Helm Chart

统一的 Fluent 日志收集栈，包含 `fluent-bit-sidecar` 和 `fluentd` 两个组件，实现 `fluent-bit-sidecar -> fluentd -> opensearch` 日志链路。

## 架构

```
HTTP Input (8888/8889) 
    ↓
fluent-bit-sidecar (Deployment)
    ↓
fluentd (Deployment)
    ↓
opensearch-cluster-master.opensearch.svc.cluster.local:9200
```

## 功能特性

- **统一 Chart**: 一个 Helm Chart 包含两个组件
- **HTTP Input**: Fluent Bit 提供两个 HTTP 输入端口（8888: order-app, 8889: user-app）
- **Forward 协议**: Fluent Bit 通过 Forward 协议将日志转发到 Fluentd
- **OpenSearch 集成**: Fluentd 自动连接到现有的 OpenSearch 服务
- **格式验证**: 自动验证日志格式，路由错误日志到错误索引
- **高可用**: 支持多副本部署和 HPA 自动扩缩容

## 前置条件

- Kubernetes 1.19+
- Helm 3.0+
- OpenSearch 服务已部署（`opensearch-cluster-master.opensearch.svc.cluster.local:9200`）

## 安装

### 基本安装

```bash
helm install fluent ./charts/fluent \
  --namespace logging \
  --create-namespace
```

### 自定义配置安装

```bash
helm install fluent ./charts/fluent \
  --namespace logging \
  --create-namespace \
  --set fluentd.opensearch.service.name=opensearch-cluster-master \
  --set fluentd.opensearch.service.namespace=opensearch \
  --set fluentBit.replicaCount=3 \
  --set fluentd.replicaCount=3
```

## 配置说明

### values.yaml 主要配置项

```yaml
# Fluent Bit 配置
fluentBit:
  enabled: true
  replicaCount: 2
  # HTTP Input 端口
  config:
    httpInput:
      orderApp:
        port: 8888
        tag: order.log
      userApp:
        port: 8889
        tag: user.log

# Fluentd 配置
fluentd:
  enabled: true
  replicaCount: 2
  # OpenSearch 配置（连接到现有服务）
  opensearch:
    useService: true
    service:
      name: opensearch-cluster-master
      namespace: opensearch
      port: 9200
    scheme: http
    verifySsl: false
```

## 使用方式

### 从应用发送日志

#### Order App 日志

```bash
curl -X POST http://fluent-fluent-bit.logging.svc.cluster.local:8888 \
  -H "Content-Type: application/json" \
  -d '{
    "message": "[ORDER] Order created successfully",
    "level": "INFO",
    "order_id": "ORD-001",
    "user_id": "USER-123",
    "amount": "99.99"
  }'
```

#### User App 日志

```bash
curl -X POST http://fluent-fluent-bit.logging.svc.cluster.local:8889 \
  -H "Content-Type: application/json" \
  -d '{
    "message": "[USER] User login successful",
    "level": "INFO",
    "user_id": "USER-789",
    "action": "login",
    "ip_address": "192.168.1.100"
  }'
```

## 验证部署

### 检查 Pod 状态

```bash
kubectl get pods -n logging -l app.kubernetes.io/name=fluent
```

### 检查 Service

```bash
kubectl get svc -n logging -l app.kubernetes.io/name=fluent
```

### 检查日志

```bash
# Fluent Bit 日志
kubectl logs -n logging -l app.kubernetes.io/component=fluent-bit --tail=50

# Fluentd 日志
kubectl logs -n logging -l app.kubernetes.io/component=fluentd --tail=50
```

### 测试 HTTP Input

```bash
# 从集群内测试
kubectl run -it --rm test-curl --image=curlimages/curl:latest --restart=Never -- \
  curl -X POST http://fluent-fluent-bit.logging.svc.cluster.local:8888 \
  -H "Content-Type: application/json" \
  -d '{"message":"[ORDER] Test log","level":"INFO","order_id":"ORD-TEST"}'
```

## 卸载

```bash
helm uninstall fluent --namespace logging
```

## 故障排查

### Pod 无法启动

1. 检查 ConfigMap：
   ```bash
   kubectl get configmap -n logging -l app.kubernetes.io/name=fluent
   ```

2. 检查 PVC：
   ```bash
   kubectl get pvc -n logging -l app.kubernetes.io/name=fluent
   ```

3. 检查 OpenSearch 服务：
   ```bash
   kubectl get svc -n opensearch opensearch-cluster-master
   ```

### 日志无法发送到 Fluentd

1. 检查 Fluentd 服务：
   ```bash
   kubectl get svc -n logging fluent-fluentd
   ```

2. 测试网络连接：
   ```bash
   kubectl exec -it -n logging <fluent-bit-pod> -- \
     nc -zv fluent-fluentd.logging.svc.cluster.local 24224
   ```

### 日志无法写入 OpenSearch

1. 检查 OpenSearch 连接：
   ```bash
   kubectl exec -it -n logging <fluentd-pod> -- \
     curl -f http://opensearch-cluster-master.opensearch.svc.cluster.local:9200/_cluster/health
   ```

2. 检查 Fluentd 日志中的错误：
   ```bash
   kubectl logs -n logging <fluentd-pod> | grep -i error
   ```

## 参考

- [Docker Compose 配置](../docker-compose-fluentd-3.yaml)
- [curl 格式文档](../FLUENT_BIT_HTTP_CURL_FORMAT.md)
- [OpenSearch Chart](../../_k8s/devops-infra-helm/charts/opensearch)
