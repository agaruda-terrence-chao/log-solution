# Kubernetes 部署指南

本文档说明如何在 Kubernetes 环境中部署完整的日志收集链路：`fluent-bit-sidecar -> fluentd-v3 -> opensearch`。

## 架构概览

```
┌─────────────────┐
│  Order App      │ ──HTTP POST──┐
│  User App       │ ──HTTP POST──┤
└─────────────────┘              │
                                 ▼
                    ┌──────────────────────┐
                    │ fluent-bit-sidecar   │
                    │ (Deployment)         │
                    │ Port: 8888, 8889     │
                    └──────────────────────┘
                                 │
                                 │ Forward Protocol
                                 ▼
                    ┌──────────────────────┐
                    │ fluentd-v3           │
                    │ (Deployment)        │
                    │ Port: 24224          │
                    └──────────────────────┘
                                 │
                                 │ HTTP/HTTPS
                                 ▼
                    ┌──────────────────────┐
                    │ OpenSearch           │
                    │ (StatefulSet)        │
                    │ Port: 9200           │
                    └──────────────────────┘
```

## 前置条件

1. **Kubernetes 集群** (1.19+)
2. **Helm 3.0+** 已安装
3. **OpenSearch 服务** 已部署（或使用现有的 OpenSearch 集群）
4. **StorageClass** 已配置（用于 PVC）

## 部署步骤

### 步骤 1: 创建命名空间

```bash
kubectl create namespace logging
```

### 步骤 2: 部署 Fluentd v3

Fluentd v3 需要先部署，因为 fluent-bit-sidecar 依赖它。

```bash
cd charts

helm install fluentd-v3 ./fluentd-v3 \
  --namespace logging \
  --set opensearch.service.name=opensearch-cluster-master \
  --set opensearch.service.namespace=opensearch \
  --set opensearch.useService=true \
  --set opensearch.scheme=http \
  --set opensearch.verifySsl=false
```

**配置说明**:
- `opensearch.service.name`: OpenSearch 服务名称
- `opensearch.service.namespace`: OpenSearch 服务所在命名空间
- `opensearch.useService`: 使用 Service 而不是 Ingress
- `opensearch.scheme`: HTTP 或 HTTPS
- `opensearch.verifySsl`: 是否验证 SSL 证书

**验证部署**:
```bash
kubectl get pods -n logging -l app.kubernetes.io/name=fluentd-v3
kubectl get svc -n logging fluentd-v3
```

### 步骤 3: 部署 Fluent Bit Sidecar

```bash
helm install fluent-bit-sidecar ./fluent-bit-sidecar \
  --namespace logging \
  --set fluentd.service.name=fluentd-v3 \
  --set fluentd.service.namespace=logging
```

**配置说明**:
- `fluentd.service.name`: Fluentd v3 服务名称
- `fluentd.service.namespace`: Fluentd v3 服务所在命名空间

**验证部署**:
```bash
kubectl get pods -n logging -l app.kubernetes.io/name=fluent-bit-sidecar
kubectl get svc -n logging fluent-bit-sidecar
```

### 步骤 4: 验证完整链路

#### 4.1 测试 Order App 日志发送

```bash
kubectl run -it --rm test-order-app --image=curlimages/curl:latest --restart=Never -- \
  curl -X POST http://fluent-bit-sidecar.logging.svc.cluster.local:8888 \
  -H "Content-Type: application/json" \
  -d '{
    "message": "[ORDER] Test order log from K8S",
    "level": "INFO",
    "order_id": "ORD-K8S-001",
    "user_id": "USER-K8S-001",
    "amount": "99.99",
    "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")'"
  }'
```

#### 4.2 测试 User App 日志发送

```bash
kubectl run -it --rm test-user-app --image=curlimages/curl:latest --restart=Never -- \
  curl -X POST http://fluent-bit-sidecar.logging.svc.cluster.local:8889 \
  -H "Content-Type: application/json" \
  -d '{
    "message": "[USER] Test user log from K8S",
    "level": "INFO",
    "user_id": "USER-K8S-002",
    "action": "login",
    "ip_address": "10.0.0.1",
    "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")'"
  }'
```

#### 4.3 检查 OpenSearch 索引

```bash
# 查询 Order App 正常日志
kubectl run -it --rm test-opensearch --image=curlimages/curl:latest --restart=Never -- \
  curl -X GET "http://opensearch-cluster-master.opensearch.svc.cluster.local:9200/order-logs-*/_count?q=service_name:order-app&pretty"

# 查询 User App 正常日志
kubectl run -it --rm test-opensearch --image=curlimages/curl:latest --restart=Never -- \
  curl -X GET "http://opensearch-cluster-master.opensearch.svc.cluster.local:9200/user-logs-*/_count?q=service_name:user-app&pretty"
```

## 配置自定义

### 使用自定义 values.yaml

创建 `my-values.yaml`:

```yaml
# fluentd-v3 values
opensearch:
  service:
    name: my-opensearch
    namespace: my-namespace
  useService: true
  scheme: http

replicaCount: 3
```

部署时使用:

```bash
helm install fluentd-v3 ./fluentd-v3 \
  --namespace logging \
  -f my-values.yaml
```

## 监控和调试

### 查看 Pod 状态

```bash
# 所有日志相关 Pod
kubectl get pods -n logging

# Fluent Bit Sidecar
kubectl get pods -n logging -l app.kubernetes.io/name=fluent-bit-sidecar

# Fluentd v3
kubectl get pods -n logging -l app.kubernetes.io/name=fluentd-v3
```

### 查看日志

```bash
# Fluent Bit Sidecar 日志
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit-sidecar --tail=100

# Fluentd v3 日志
kubectl logs -n logging -l app.kubernetes.io/name=fluentd-v3 --tail=100
```

### 检查配置

```bash
# Fluent Bit 配置
kubectl get configmap -n logging fluent-bit-sidecar-config -o yaml

# Fluentd 主配置
kubectl get configmap -n logging fluentd-v3-config -o yaml

# Fluentd 服务配置
kubectl get configmap -n logging fluentd-v3-confd -o yaml
```

### 进入 Pod 调试

```bash
# Fluent Bit
kubectl exec -it -n logging <fluent-bit-pod> -- /bin/sh

# Fluentd
kubectl exec -it -n logging <fluentd-pod> -- /bin/sh
```

## 故障排查

### 问题 1: Fluent Bit 无法连接到 Fluentd

**症状**: Fluent Bit Pod 日志显示连接错误

**排查**:
```bash
# 检查 Fluentd 服务是否存在
kubectl get svc -n logging fluentd-v3

# 检查 Fluentd Pod 是否运行
kubectl get pods -n logging -l app.kubernetes.io/name=fluentd-v3

# 测试网络连接
kubectl exec -it -n logging <fluent-bit-pod> -- \
  nc -zv fluentd-v3.logging.svc.cluster.local 24224
```

**解决**: 确保 Fluentd v3 已正确部署且服务可访问

### 问题 2: Fluentd 无法连接到 OpenSearch

**症状**: Fluentd Pod 日志显示 OpenSearch 连接错误

**排查**:
```bash
# 检查 OpenSearch 服务
kubectl get svc -n <opensearch-namespace> <opensearch-service>

# 测试连接
kubectl exec -it -n logging <fluentd-pod> -- \
  curl -f http://<opensearch-service>.<namespace>.svc.cluster.local:9200/_cluster/health
```

**解决**: 检查 OpenSearch 服务配置和网络策略

### 问题 3: 日志未出现在 OpenSearch

**排查步骤**:
1. 检查 Fluent Bit 是否收到日志
2. 检查 Fluentd 是否处理日志
3. 检查 OpenSearch 索引是否存在
4. 检查 Buffer 是否积压

```bash
# 检查 Buffer 目录
kubectl exec -it -n logging <fluentd-pod> -- ls -lh /fluentd/buffers/

# 检查错误日志
kubectl exec -it -n logging <fluentd-pod> -- cat /fluentd/logs/order_errors.log
```

## 升级

### 升级 Fluentd v3

```bash
helm upgrade fluentd-v3 ./fluentd-v3 \
  --namespace logging \
  --set opensearch.service.name=opensearch-cluster-master
```

### 升级 Fluent Bit Sidecar

```bash
helm upgrade fluent-bit-sidecar ./fluent-bit-sidecar \
  --namespace logging \
  --set fluentd.service.name=fluentd-v3
```

## 卸载

### 卸载顺序

**重要**: 先卸载 fluent-bit-sidecar，再卸载 fluentd-v3

```bash
# 1. 卸载 Fluent Bit Sidecar
helm uninstall fluent-bit-sidecar --namespace logging

# 2. 卸载 Fluentd v3
helm uninstall fluentd-v3 --namespace logging

# 3. 清理 PVC (可选)
kubectl delete pvc -n logging -l app.kubernetes.io/name=fluent-bit-sidecar
kubectl delete pvc -n logging -l app.kubernetes.io/name=fluentd-v3
```

## 生产环境建议

### 1. 资源限制

根据实际负载调整资源请求和限制：

```yaml
# fluent-bit-sidecar values.yaml
resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    cpu: 1000m
    memory: 1Gi

# fluentd-v3 values.yaml
resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 2000m
    memory: 2Gi
```

### 2. 高可用

- **Fluent Bit Sidecar**: 建议 2-3 个副本
- **Fluentd v3**: 建议 2-4 个副本，启用 HPA

```yaml
# fluentd-v3 values.yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 4
  targetCPUUtilizationPercentage: 80
```

### 3. 存储

- 根据日志量调整 PVC 大小
- 使用高性能 StorageClass（如 SSD）
- 定期清理旧日志

### 4. 监控

建议配置 Prometheus 监控：
- Fluent Bit metrics
- Fluentd metrics
- OpenSearch cluster health

### 5. 安全

- 使用 NetworkPolicy 限制网络访问
- 启用 TLS 连接（如果 OpenSearch 支持）
- 使用 ServiceAccount 和 RBAC

## 参考

- [Fluent Bit Sidecar README](./fluent-bit-sidecar/README.md)
- [Fluentd v3 README](./fluentd-v3/README.md)
- [Docker Compose 配置](../docker-compose-fluentd-3.yaml)
- [curl 格式文档](../FLUENT_BIT_HTTP_CURL_FORMAT.md)
