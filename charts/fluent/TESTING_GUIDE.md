# Fluent Bit HTTP Input - Kubernetes 测试指南

本文档说明如何在 Kubernetes 环境中通过 curl 命令向 Fluent Bit HTTP input 发送 order-app 和 user-app 的日志。

## 前置条件

1. Fluent Bit 和 Fluentd 已成功部署到 Kubernetes
2. 确认 Pod 状态为 `Running` 且 `READY 1/1`
3. 确认 Service 已创建并可以访问

### 检查部署状态

```bash
# 检查 Fluent Bit Pods
kubectl get pods -n fluent -l app.kubernetes.io/component=fluent-bit

# 检查 Fluentd Pods
kubectl get pods -n fluent -l app.kubernetes.io/component=fluentd

# 检查 Fluent Bit Service
kubectl get svc -n fluent fluent-fluent-bit
```

## 服务地址

根据 Helm chart 配置：

- **Namespace**: `fluent`
- **Service Name**: `fluent-fluent-bit`
- **Order App 端口**: `8888` (Tag: `order.log`)
- **User App 端口**: `8889` (Tag: `user.log`)
- **协议**: HTTP POST
- **Content-Type**: `application/json`

### 服务访问方式

#### 方式 1: 从集群内部 Pod 访问（推荐）

使用 Service 的完整 DNS 名称：
```
http://fluent-fluent-bit.fluent.svc.cluster.local:8888  # Order App
http://fluent-fluent-bit.fluent.svc.cluster.local:8889  # User App
```

#### 方式 2: 使用 Port Forward（本地测试）

```bash
# 在终端 1: 转发 Order App 端口
kubectl port-forward -n fluent svc/fluent-fluent-bit 8888:8888

# 在终端 2: 转发 User App 端口（需要另一个终端）
kubectl port-forward -n fluent svc/fluent-fluent-bit 8889:8889
```

然后使用 `http://localhost:8888` 和 `http://localhost:8889`

## Order App 日志格式

### 必需字段
- `message`: 日志消息内容（会被 Fluent Bit 重命名为 `log`）
- `level`: 日志级别（`INFO` 或 `ERROR`）

### 可选字段
- `order_id`: 订单 ID
- `user_id`: 用户 ID
- `amount`: 订单金额
- `timestamp`: 时间戳（ISO 8601 格式）

### curl 命令示例

#### 1. Order App - INFO 级别日志（从集群内部 Pod）

```bash
kubectl run -it --rm test-order-info-$(date +%s) \
  --image=curlimages/curl:latest \
  --restart=Never \
  -n fluent \
  -- curl -X POST http://fluent-fluent-bit.fluent.svc.cluster.local:8888 \
    -H "Content-Type: application/json" \
    -d '{
      "message": "[ORDER] Order created successfully - Order ID: ORD-001, User: USER-123, Amount: $99.99",
      "level": "INFO",
      "order_id": "ORD-001",
      "user_id": "USER-123",
      "amount": "99.99",
      "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")'"
    }'
```

#### 2. Order App - ERROR 级别日志（从集群内部 Pod）

```bash
kubectl run -it --rm test-order-error-$(date +%s) \
  --image=curlimages/curl:latest \
  --restart=Never \
  -n fluent \
  -- curl -X POST http://fluent-fluent-bit.fluent.svc.cluster.local:8888 \
    -H "Content-Type: application/json" \
    -d '{
      "message": "[ORDER] Payment failed - Order ID: ORD-002, User: USER-456, Amount: $199.99",
      "level": "ERROR",
      "order_id": "ORD-002",
      "user_id": "USER-456",
      "amount": "199.99",
      "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")'"
    }'
```

#### 3. Order App - 最小格式（仅必需字段）

```bash
kubectl run -it --rm test-order-minimal-$(date +%s) \
  --image=curlimages/curl:latest \
  --restart=Never \
  -n fluent \
  -- curl -X POST http://fluent-fluent-bit.fluent.svc.cluster.local:8888 \
    -H "Content-Type: application/json" \
    -d '{
      "message": "Order processing started",
      "level": "INFO"
    }'
```

#### 4. Order App - 使用 Port Forward（本地测试）

如果已设置 port-forward，可以使用：

```bash
curl -X POST http://localhost:8888 \
  -H "Content-Type: application/json" \
  -d '{
    "message": "[ORDER] Order created successfully - Order ID: ORD-001, User: USER-123, Amount: $99.99",
    "level": "INFO",
    "order_id": "ORD-001",
    "user_id": "USER-123",
    "amount": "99.99",
    "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")'"
  }'
```

## User App 日志格式

### 必需字段
- `message`: 日志消息内容（会被 Fluent Bit 重命名为 `log`）
- `level`: 日志级别（`INFO` 或 `ERROR`）

### 可选字段
- `user_id`: 用户 ID
- `action`: 用户操作类型（如：login, logout, register, profile_update, password_change, session_refresh）
- `ip_address`: IP 地址
- `timestamp`: 时间戳（ISO 8601 格式）

### curl 命令示例

#### 1. User App - INFO 级别日志（从集群内部 Pod）

```bash
kubectl run -it --rm test-user-info-$(date +%s) \
  --image=curlimages/curl:latest \
  --restart=Never \
  -n fluent \
  -- curl -X POST http://fluent-fluent-bit.fluent.svc.cluster.local:8889 \
    -H "Content-Type: application/json" \
    -d '{
      "message": "[USER] User login successful - User ID: USER-789, IP: 192.168.1.100",
      "level": "INFO",
      "user_id": "USER-789",
      "action": "login",
      "ip_address": "192.168.1.100",
      "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")'"
    }'
```

#### 2. User App - ERROR 级别日志（从集群内部 Pod）

```bash
kubectl run -it --rm test-user-error-$(date +%s) \
  --image=curlimages/curl:latest \
  --restart=Never \
  -n fluent \
  -- curl -X POST http://fluent-fluent-bit.fluent.svc.cluster.local:8889 \
    -H "Content-Type: application/json" \
    -d '{
      "message": "[USER] Authentication failed - User ID: USER-999, IP: 192.168.1.200, Reason: Invalid credentials",
      "level": "ERROR",
      "user_id": "USER-999",
      "action": "login",
      "ip_address": "192.168.1.200",
      "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")'"
    }'
```

#### 3. User App - 最小格式（仅必需字段）

```bash
kubectl run -it --rm test-user-minimal-$(date +%s) \
  --image=curlimages/curl:latest \
  --restart=Never \
  -n fluent \
  -- curl -X POST http://fluent-fluent-bit.fluent.svc.cluster.local:8889 \
    -H "Content-Type: application/json" \
    -d '{
      "message": "User session refreshed",
      "level": "INFO"
    }'
```

#### 4. User App - 使用 Port Forward（本地测试）

如果已设置 port-forward，可以使用：

```bash
curl -X POST http://localhost:8889 \
  -H "Content-Type: application/json" \
  -d '{
    "message": "[USER] User login successful - User ID: USER-789, IP: 192.168.1.100",
    "level": "INFO",
    "user_id": "USER-789",
    "action": "login",
    "ip_address": "192.168.1.100",
    "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")'"
  }'
```

## 快速测试脚本

### 一键测试所有场景（从集群内部）

```bash
#!/bin/bash

NAMESPACE="fluent"
SERVICE="fluent-fluent-bit.fluent.svc.cluster.local"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

echo "=== Testing Order App ==="

# Order App - INFO
echo "Sending Order App INFO log..."
kubectl run -it --rm test-order-info-$(date +%s) \
  --image=curlimages/curl:latest \
  --restart=Never \
  -n ${NAMESPACE} \
  -- curl -X POST http://${SERVICE}:8888 \
    -H "Content-Type: application/json" \
    -d "{\"message\":\"[ORDER] Test INFO log\",\"level\":\"INFO\",\"order_id\":\"ORD-TEST\",\"user_id\":\"USER-TEST\",\"amount\":\"99.99\",\"timestamp\":\"${TIMESTAMP}\"}"

echo -e "\n"

# Order App - ERROR
echo "Sending Order App ERROR log..."
kubectl run -it --rm test-order-error-$(date +%s) \
  --image=curlimages/curl:latest \
  --restart=Never \
  -n ${NAMESPACE} \
  -- curl -X POST http://${SERVICE}:8888 \
    -H "Content-Type: application/json" \
    -d "{\"message\":\"[ORDER] Test ERROR log\",\"level\":\"ERROR\",\"order_id\":\"ORD-ERROR\",\"user_id\":\"USER-ERROR\",\"amount\":\"199.99\",\"timestamp\":\"${TIMESTAMP}\"}"

echo -e "\n=== Testing User App ===\n"

# User App - INFO
echo "Sending User App INFO log..."
kubectl run -it --rm test-user-info-$(date +%s) \
  --image=curlimages/curl:latest \
  --restart=Never \
  -n ${NAMESPACE} \
  -- curl -X POST http://${SERVICE}:8889 \
    -H "Content-Type: application/json" \
    -d "{\"message\":\"[USER] Test INFO log\",\"level\":\"INFO\",\"user_id\":\"USER-TEST\",\"action\":\"login\",\"ip_address\":\"192.168.1.100\",\"timestamp\":\"${TIMESTAMP}\"}"

echo -e "\n"

# User App - ERROR
echo "Sending User App ERROR log..."
kubectl run -it --rm test-user-error-$(date +%s) \
  --image=curlimages/curl:latest \
  --restart=Never \
  -n ${NAMESPACE} \
  -- curl -X POST http://${SERVICE}:8889 \
    -H "Content-Type: application/json" \
    -d "{\"message\":\"[USER] Test ERROR log\",\"level\":\"ERROR\",\"user_id\":\"USER-ERROR\",\"action\":\"login\",\"ip_address\":\"192.168.1.200\",\"timestamp\":\"${TIMESTAMP}\"}"

echo -e "\n=== Test Complete ===\n"
```

### 使用 Port Forward 的测试脚本（本地）

```bash
#!/bin/bash

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

echo "=== Testing Order App ==="

# Order App - INFO
echo "Sending Order App INFO log..."
curl -X POST http://localhost:8888 \
  -H "Content-Type: application/json" \
  -d "{
    \"message\": \"[ORDER] Test INFO log\",
    \"level\": \"INFO\",
    \"order_id\": \"ORD-TEST\",
    \"user_id\": \"USER-TEST\",
    \"amount\": \"99.99\",
    \"timestamp\": \"${TIMESTAMP}\"
  }"

echo -e "\n"

# Order App - ERROR
echo "Sending Order App ERROR log..."
curl -X POST http://localhost:8888 \
  -H "Content-Type: application/json" \
  -d "{
    \"message\": \"[ORDER] Test ERROR log\",
    \"level\": \"ERROR\",
    \"order_id\": \"ORD-ERROR\",
    \"user_id\": \"USER-ERROR\",
    \"amount\": \"199.99\",
    \"timestamp\": \"${TIMESTAMP}\"
  }"

echo -e "\n=== Testing User App ===\n"

# User App - INFO
echo "Sending User App INFO log..."
curl -X POST http://localhost:8889 \
  -H "Content-Type: application/json" \
  -d "{
    \"message\": \"[USER] Test INFO log\",
    \"level\": \"INFO\",
    \"user_id\": \"USER-TEST\",
    \"action\": \"login\",
    \"ip_address\": \"192.168.1.100\",
    \"timestamp\": \"${TIMESTAMP}\"
  }"

echo -e "\n"

# User App - ERROR
echo "Sending User App ERROR log..."
curl -X POST http://localhost:8889 \
  -H "Content-Type: application/json" \
  -d "{
    \"message\": \"[USER] Test ERROR log\",
    \"level\": \"ERROR\",
    \"user_id\": \"USER-ERROR\",
    \"action\": \"login\",
    \"ip_address\": \"192.168.1.200\",
    \"timestamp\": \"${TIMESTAMP}\"
  }"

echo -e "\n=== Test Complete ===\n"
```

## 验证日志是否成功发送

### 检查 Fluent Bit Pod 日志

```bash
# 查看 Fluent Bit Pod 日志
kubectl logs -n fluent -l app.kubernetes.io/component=fluent-bit --tail=50
```

### 检查 Fluentd Pod 日志

```bash
# 查看 Fluentd Pod 日志
kubectl logs -n fluent -l app.kubernetes.io/component=fluentd --tail=50

# 过滤查看特定服务的日志
kubectl logs -n fluent -l app.kubernetes.io/component=fluentd --tail=50 | grep -i "order\|user"
```

### 检查 OpenSearch 索引

#### Order App 正常日志

```bash
kubectl run -it --rm test-opensearch-order-$(date +%s) \
  --image=curlimages/curl:latest \
  --restart=Never \
  -n fluent \
  -- curl -s "http://opensearch-cluster-master.opensearch.svc.cluster.local:9200/order-logs-*/_search?q=service_name:order-app&pretty" | head -100
```

#### Order App 错误日志

```bash
kubectl run -it --rm test-opensearch-order-error-$(date +%s) \
  --image=curlimages/curl:latest \
  --restart=Never \
  -n fluent \
  -- curl -s "http://opensearch-cluster-master.opensearch.svc.cluster.local:9200/order-error-logs-*/_search?q=service_name:order-app&pretty" | head -100
```

#### User App 正常日志

```bash
kubectl run -it --rm test-opensearch-user-$(date +%s) \
  --image=curlimages/curl:latest \
  --restart=Never \
  -n fluent \
  -- curl -s "http://opensearch-cluster-master.opensearch.svc.cluster.local:9200/user-logs-*/_search?q=service_name:user-app&pretty" | head -100
```

#### User App 错误日志

```bash
kubectl run -it --rm test-opensearch-user-error-$(date +%s) \
  --image=curlimages/curl:latest \
  --restart=Never \
  -n fluent \
  -- curl -s "http://opensearch-cluster-master.opensearch.svc.cluster.local:9200/user-error-logs-*/_search?q=service_name:user-app&pretty" | head -100
```

## 响应说明

### 成功响应
- **状态码**: `200` 或 `201`
- **响应体**: 通常为空或包含确认信息

### 错误响应
- **状态码**: `400` (Bad Request) - JSON 格式错误
- **状态码**: `404` (Not Found) - 路径不存在（Fluent Bit HTTP input 接受任何路径）
- **状态码**: `405` (Method Not Allowed) - 非 POST 请求
- **状态码**: `503` (Service Unavailable) - Fluent Bit Service 不可用

## 注意事项

1. **Namespace**: 确保所有命令都在正确的 namespace (`fluent`) 中执行

2. **Service DNS**: 
   - 从集群内部访问时使用完整 DNS: `fluent-fluent-bit.fluent.svc.cluster.local`
   - 同一 namespace 内可以简化为: `fluent-fluent-bit`

3. **字段映射**: 
   - HTTP POST 的 `message` 字段会被 Fluent Bit 的 modify filter 重命名为 `log`
   - Fluentd 会同时检查 `log` 和 `message` 字段

4. **必需字段验证**: 
   - Fluentd 会验证 `message`/`log` 和 `level` 字段是否存在
   - 缺少必需字段的日志会被路由到错误索引

5. **错误级别检测**:
   - `level = "ERROR"` 的日志会被自动路由到错误索引
   - 日志内容包含 "ERROR" 字符串的也会被识别为错误

6. **时间戳格式**: 
   - 建议使用 ISO 8601 格式：`YYYY-MM-DDTHH:mm:ss.sssZ`
   - 如果不提供，Fluentd 会添加 `processed_at` 字段

7. **临时 Pod 清理**: 
   - 使用 `kubectl run` 创建的临时 Pod 会在命令执行完成后自动删除（`--rm` 标志）
   - 如果命令失败，可能需要手动清理：`kubectl delete pod -n fluent -l run=test-*`

## 故障排查

### Pod 无法连接到 Service

```bash
# 检查 Service 是否存在
kubectl get svc -n fluent fluent-fluent-bit

# 检查 Service 的 Endpoints
kubectl get endpoints -n fluent fluent-fluent-bit

# 检查 Fluent Bit Pods 是否运行
kubectl get pods -n fluent -l app.kubernetes.io/component=fluent-bit
```

### 日志未出现在 OpenSearch

```bash
# 检查 Fluentd Pods 状态
kubectl get pods -n fluent -l app.kubernetes.io/component=fluentd

# 检查 Fluentd 日志中的错误
kubectl logs -n fluent -l app.kubernetes.io/component=fluentd --tail=100 | grep -i error

# 检查 OpenSearch 连接
kubectl run -it --rm test-opensearch-connection-$(date +%s) \
  --image=curlimages/curl:latest \
  --restart=Never \
  -n fluent \
  -- curl -s "http://opensearch-cluster-master.opensearch.svc.cluster.local:9200/_cluster/health?pretty"
```

## 参考

- Docker Compose 环境测试指南: `../../FLUENT_BIT_HTTP_CURL_FORMAT.md`
- Fluent Bit HTTP Input 配置: `../../fluent-bit-sidecar/fluent-bit.conf`
- Order App Fluentd 配置: `../../fluentd/conf.d/service-order-app-3.conf`
- User App Fluentd 配置: `../../fluentd/conf.d/service-user-app-3.conf`
- Helm Chart 部署指南: `DEPLOYMENT_GUIDE.md`
