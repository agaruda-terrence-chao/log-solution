# Fluent Bit HTTP Input - curl 命令格式

本文档说明如何通过 curl 命令向 Fluent Bit HTTP input 发送 order-app 和 user-app 的日志。

## 配置说明

根据 `fluent-bit-sidecar/fluent-bit.conf` 配置：

- **Order App**: 端口 `8888`，Tag `order.log`
- **User App**: 端口 `8889`，Tag `user.log`
- **协议**: HTTP POST
- **Content-Type**: `application/json`
- **格式**: JSON

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

#### 1. Order App - INFO 级别日志

```bash
curl -X POST http://localhost:8888 \
  -H "Content-Type: application/json" \
  -d '{
    "message": "[ORDER] Order created successfully - Order ID: ORD-001, User: USER-123, Amount: $99.99",
    "level": "INFO",
    "order_id": "ORD-001",
    "user_id": "USER-123",
    "amount": "99.99",
    "timestamp": "2026-01-13T15:30:00.000Z"
  }'
```

#### 2. Order App - ERROR 级别日志

```bash
curl -X POST http://localhost:8888 \
  -H "Content-Type: application/json" \
  -d '{
    "message": "[ORDER] Payment failed - Order ID: ORD-002, User: USER-456, Amount: $199.99",
    "level": "ERROR",
    "order_id": "ORD-002",
    "user_id": "USER-456",
    "amount": "199.99",
    "timestamp": "2026-01-13T15:31:00.000Z"
  }'
```

#### 3. Order App - 最小格式（仅必需字段）

```bash
curl -X POST http://localhost:8888 \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Order processing started",
    "level": "INFO"
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

#### 1. User App - INFO 级别日志

```bash
curl -X POST http://localhost:8889 \
  -H "Content-Type: application/json" \
  -d '{
    "message": "[USER] User login successful - User ID: USER-789, IP: 192.168.1.100",
    "level": "INFO",
    "user_id": "USER-789",
    "action": "login",
    "ip_address": "192.168.1.100",
    "timestamp": "2026-01-13T15:32:00.000Z"
  }'
```

#### 2. User App - ERROR 级别日志

```bash
curl -X POST http://localhost:8889 \
  -H "Content-Type: application/json" \
  -d '{
    "message": "[USER] Authentication failed - User ID: USER-999, IP: 192.168.1.200, Reason: Invalid credentials",
    "level": "ERROR",
    "user_id": "USER-999",
    "action": "login",
    "ip_address": "192.168.1.200",
    "timestamp": "2026-01-13T15:33:00.000Z"
  }'
```

#### 3. User App - 最小格式（仅必需字段）

```bash
curl -X POST http://localhost:8889 \
  -H "Content-Type: application/json" \
  -d '{
    "message": "User session refreshed",
    "level": "INFO"
  }'
```

## 完整示例脚本

### Order App 测试脚本

```bash
#!/bin/bash

# Order App - INFO 日志
echo "Sending Order App INFO log..."
curl -X POST http://localhost:8888 \
  -H "Content-Type: application/json" \
  -d '{
    "message": "[ORDER] Order created successfully - Order ID: ORD-TEST-001, User: USER-TEST-001, Amount: $99.99",
    "level": "INFO",
    "order_id": "ORD-TEST-001",
    "user_id": "USER-TEST-001",
    "amount": "99.99",
    "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")'"
  }'

echo -e "\n"

# Order App - ERROR 日志
echo "Sending Order App ERROR log..."
curl -X POST http://localhost:8888 \
  -H "Content-Type: application/json" \
  -d '{
    "message": "[ORDER] Payment failed - Order ID: ORD-ERROR-001, User: USER-ERROR-001, Amount: $199.99",
    "level": "ERROR",
    "order_id": "ORD-ERROR-001",
    "user_id": "USER-ERROR-001",
    "amount": "199.99",
    "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")'"
  }'

echo -e "\n"
```

### User App 测试脚本

```bash
#!/bin/bash

# User App - INFO 日志
echo "Sending User App INFO log..."
curl -X POST http://localhost:8889 \
  -H "Content-Type: application/json" \
  -d '{
    "message": "[USER] User login successful - User ID: USER-TEST-002, IP: 192.168.1.100",
    "level": "INFO",
    "user_id": "USER-TEST-002",
    "action": "login",
    "ip_address": "192.168.1.100",
    "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")'"
  }'

echo -e "\n"

# User App - ERROR 日志
echo "Sending User App ERROR log..."
curl -X POST http://localhost:8889 \
  -H "Content-Type: application/json" \
  -d '{
    "message": "[USER] Authentication failed - User ID: USER-ERROR-002, IP: 192.168.1.200, Reason: Invalid credentials",
    "level": "ERROR",
    "user_id": "USER-ERROR-002",
    "action": "login",
    "ip_address": "192.168.1.200",
    "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")'"
  }'

echo -e "\n"
```

## 响应说明

### 成功响应
- **状态码**: `200` 或 `201`
- **响应体**: 通常为空或包含确认信息

### 错误响应
- **状态码**: `400` (Bad Request) - JSON 格式错误
- **状态码**: `404` (Not Found) - 路径不存在（Fluent Bit HTTP input 接受任何路径）
- **状态码**: `405` (Method Not Allowed) - 非 POST 请求

## 注意事项

1. **路径**: Fluent Bit HTTP input 接受任何路径，可以使用 `/`、`/api/v1/order`、`/api/v1/user` 等，但建议使用根路径 `/` 或注释中提到的路径。

2. **字段映射**: 
   - HTTP POST 的 `message` 字段会被 Fluent Bit 的 modify filter 重命名为 `log`
   - Fluentd 会同时检查 `log` 和 `message` 字段

3. **必需字段验证**: 
   - Fluentd 会验证 `message`/`log` 和 `level` 字段是否存在
   - 缺少必需字段的日志会被路由到错误索引

4. **错误级别检测**:
   - `level = "ERROR"` 的日志会被自动路由到错误索引
   - 日志内容包含 "ERROR" 字符串的也会被识别为错误

5. **时间戳格式**: 
   - 建议使用 ISO 8601 格式：`YYYY-MM-DDTHH:mm:ss.sssZ`
   - 如果不提供，Fluentd 会添加 `processed_at` 字段

## 验证日志是否成功发送

### 检查 Fluent Bit 日志
```bash
docker logs log-solution-fluentd-3-fluent-bit-sidecar | tail -20
```

### 检查 OpenSearch 索引

#### Order App 正常日志
```bash
curl -X GET "http://localhost:9200/order-logs-*/_search?q=service_name:order-app&pretty" | head -50
```

#### Order App 错误日志
```bash
curl -X GET "http://localhost:9200/order-error-logs-*/_search?q=service_name:order-app&pretty" | head -50
```

#### User App 正常日志
```bash
curl -X GET "http://localhost:9200/user-logs-*/_search?q=service_name:user-app&pretty" | head -50
```

#### User App 错误日志
```bash
curl -X GET "http://localhost:9200/user-error-logs-*/_search?q=service_name:user-app&pretty" | head -50
```

## 快速测试命令

### 一键测试所有场景

```bash
# Order App - INFO
curl -X POST http://localhost:8888 -H "Content-Type: application/json" -d '{"message":"[ORDER] Test INFO log","level":"INFO","order_id":"ORD-TEST","user_id":"USER-TEST","amount":"99.99"}'

# Order App - ERROR
curl -X POST http://localhost:8888 -H "Content-Type: application/json" -d '{"message":"[ORDER] Test ERROR log","level":"ERROR","order_id":"ORD-ERROR","user_id":"USER-ERROR","amount":"199.99"}'

# User App - INFO
curl -X POST http://localhost:8889 -H "Content-Type: application/json" -d '{"message":"[USER] Test INFO log","level":"INFO","user_id":"USER-TEST","action":"login","ip_address":"192.168.1.100"}'

# User App - ERROR
curl -X POST http://localhost:8889 -H "Content-Type: application/json" -d '{"message":"[USER] Test ERROR log","level":"ERROR","user_id":"USER-ERROR","action":"login","ip_address":"192.168.1.200"}'
```

## 参考

- Fluent Bit HTTP Input 配置: `fluent-bit-sidecar/fluent-bit.conf`
- Order App Fluentd 配置: `fluentd/conf.d/service-order-app-3.conf`
- User App Fluentd 配置: `fluentd/conf.d/service-user-app-3.conf`
- 压力测试脚本: `tests/load_test_order_app.js`, `tests/load_test_user_app.js`
