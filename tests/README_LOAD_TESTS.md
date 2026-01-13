# 压力测试脚本使用指南

本目录包含针对 Order App 和 User App 的 K6 压力测试脚本。

## 脚本说明

### load_test_order_app.js

针对 **Order App** 的压力测试脚本，发送日志到 Fluent Bit HTTP input (端口 **8888**)。

**测试配置：**
- **目标 URL**: `http://localhost:8888`
- **QPS**: 1000 请求/秒（可通过环境变量调整）
- **持续时间**: 5 分钟
- **预分配 VUs**: 100
- **最大 VUs**: 500

**测试数据：**
- 90% INFO 级别日志（订单创建成功）
- 10% ERROR 级别日志（支付失败）
- 包含字段：
  - `message`: 日志消息
  - `level`: 日志级别（INFO/ERROR）
  - `order_id`: 订单 ID（格式：ORD-{timestamp}-{random}）
  - `user_id`: 用户 ID（格式：USER-{random}）
  - `amount`: 订单金额（随机生成，10-1010）
  - `timestamp`: ISO 8601 时间戳

**性能阈值：**
- 95% 请求响应时间 < 200ms
- 99% 请求响应时间 < 500ms
- 错误率 < 1%
- 中位数响应时间 < 100ms
- Order 创建成功率 > 99%

### load_test_user_app.js

针对 **User App** 的压力测试脚本，发送日志到 Fluent Bit HTTP input (端口 **8889**)。

**测试配置：**
- **目标 URL**: `http://localhost:8889`
- **QPS**: 1000 请求/秒（可通过环境变量调整）
- **持续时间**: 5 分钟
- **预分配 VUs**: 100
- **最大 VUs**: 500

**测试数据：**
- 90% INFO 级别日志（用户操作成功）
- 10% ERROR 级别日志（认证失败）
- 包含字段：
  - `message`: 日志消息
  - `level`: 日志级别（INFO/ERROR）
  - `user_id`: 用户 ID（格式：USER-{random}）
  - `action`: 用户操作类型（login, logout, register, profile_update, password_change, session_refresh）
  - `ip_address`: IP 地址（随机生成）
  - `timestamp`: ISO 8601 时间戳

**性能阈值：**
- 95% 请求响应时间 < 200ms
- 99% 请求响应时间 < 500ms
- 错误率 < 1%
- 中位数响应时间 < 100ms
- 用户操作成功率 > 99%

## 快速开始

### 方法 1: 使用便捷脚本（推荐）

```bash
cd playground/log-solution/tests

# 交互式菜单
./run_load_tests.sh

# 或直接运行
./run_load_tests.sh order    # Order App 测试
./run_load_tests.sh user     # User App 测试
./run_load_tests.sh both     # 同时运行两个测试
./run_load_tests.sh quick    # 快速测试（10秒，低 QPS）
```

### 方法 2: 直接使用 k6

```bash
cd playground/log-solution/tests

# Order App 压力测试
k6 run load_test_order_app.js

# User App 压力测试
k6 run load_test_user_app.js
```

### 方法 3: 使用 Docker 运行 k6

```bash
cd playground/log-solution/tests

# Order App
docker run --rm -i -v $(pwd):/scripts -w /scripts --network host grafana/k6 run load_test_order_app.js

# User App
docker run --rm -i -v $(pwd):/scripts -w /scripts --network host grafana/k6 run load_test_user_app.js
```

## 前置条件

1. **服务运行**：确保 Fluent Bit 和 Fluentd 服务正在运行
   ```bash
   cd playground/log-solution
   docker-compose -f docker-compose-fluentd-3.yaml up -d fluent-bit-sidecar fluentd opensearch
   ```

2. **k6 安装**：安装 k6（参考 [README_K6.md](./README_K6.md)）
   ```bash
   # macOS
   brew install k6
   
   # 或使用 Docker
   docker pull grafana/k6
   ```

## 自定义参数

### 调整 QPS

```bash
# 使用环境变量
TARGET_QPS=500 k6 run load_test_order_app.js
TARGET_QPS=500 k6 run load_test_user_app.js
```

然后在脚本中修改：
```javascript
rate: parseInt(__ENV.TARGET_QPS) || 1000,
```

### 调整持续时间

```bash
# 运行 2 分钟
k6 run --duration 2m load_test_order_app.js
k6 run --duration 2m load_test_user_app.js
```

### 输出结果到文件

```bash
# JSON 格式
k6 run --out json=results_order_app.json load_test_order_app.js
k6 run --out json=results_user_app.json load_test_user_app.js

# InfluxDB（用于 Grafana 可视化）
k6 run --out influxdb=http://localhost:8086/k6 load_test_order_app.js
```

## 监控建议

### 1. Fluent Bit 服务

```bash
# 查看容器状态
docker stats log-solution-fluentd-3-fluent-bit-sidecar

# 查看日志
docker logs -f log-solution-fluentd-3-fluent-bit-sidecar

# 检查 buffer 使用情况
du -sh playground/log-solution/fluent-bit-sidecar/flb-storage/
```

### 2. Fluentd 服务

```bash
# 查看容器状态
docker stats log-solution-fluentd-3

# 查看日志
docker logs -f log-solution-fluentd-3
```

### 3. OpenSearch 索引

```bash
# Order App 正常日志
watch -n 1 'curl -s "http://localhost:9200/order-logs-*/_count?pretty"'

# Order App 错误日志
watch -n 1 'curl -s "http://localhost:9200/order-error-logs-*/_count?pretty"'

# User App 正常日志
watch -n 1 'curl -s "http://localhost:9200/user-logs-*/_count?pretty"'

# User App 错误日志
watch -n 1 'curl -s "http://localhost:9200/user-error-logs-*/_count?pretty"'
```

### 4. 系统资源

```bash
# CPU 和内存
top
# 或
htop

# 网络流量
iftop
```

## 测试结果验证

测试完成后，脚本会自动：

1. **查询 OpenSearch 索引**：
   - 正常日志数量（`order-logs-*` / `user-logs-*`）
   - 错误日志数量（`order-error-logs-*` / `user-error-logs-*`）
   - 最新日志示例

2. **显示统计信息**：
   - 总请求数
   - 成功率
   - 响应时间分布
   - 错误率

## 示例输出

```
          /\      |‾‾| /‾‾/   /‾‾/
     /\  /  \     |  |/  /   /  /
    /  \/    \    |     (   /   ‾‾\
   /          \   |  |\  \ |  (‾)  |
  / __________ \  |__| \__\ \_____/ .io

  execution: local
     script: load_test_order_app.js
     output: -

  scenarios: (100.00%) 1 scenario, 500 max VUs, 5m0s max duration
           ✓ setup
           ✓ teardown

     ✓ status is 200
     ✓ response received
     ✓ errors.........................: 0.00%  ✓ 0     ✗ 300000
     ✓ http_req_duration..............: avg=45.23ms min=12ms med=38ms max=234ms p(90)=89ms p(95)=156ms p(99)=198ms
     ✓ response_time..................: avg=45.23ms min=12ms med=38ms max=234ms
     ✓ order_created..................: 90.00% ✓ 270000 ✗ 0

     checks.........................: 100.00% ✓ 600000 ✗ 0
     data_received..................: 45 MB   150 kB/s
     data_sent......................: 23 MB   77 kB/s
     http_req_duration..............: avg=45.23ms min=12ms med=38ms max=234ms
     http_reqs......................: 300000  1000.00/s
     iterations.....................: 300000  1000.00/s
     vus............................: 100     min=100 max=100
     vus_max........................: 500     min=500 max=500

📊 Load test completed at 2026-01-13T15:30:00.000Z
⏰ Test started at: 2026-01-13T15:25:00.000Z
🎯 Target URL: http://localhost:8888
📦 Service: order-app

✅ Normal logs in OpenSearch (order-logs-*): 270,000
⚠️  Error logs in OpenSearch (order-error-logs-*): 30,000

📝 Latest log sample:
   Order ID: ORD-1705149000000-123456
   Level: INFO
   Timestamp: 2026-01-13T15:30:00.000Z
```

## 故障排查

### 错误：连接被拒绝

```bash
# 检查服务是否运行
docker ps | grep fluent-bit-sidecar

# 检查端口是否开放
curl http://localhost:8888
curl http://localhost:8889
```

### 错误率过高

- 降低 QPS：`TARGET_QPS=500 k6 run load_test_order_app.js`
- 检查 Fluent Bit 服务资源使用情况
- 检查 Fluentd 处理能力
- 检查 OpenSearch 写入性能

### 响应时间过长

- 检查服务资源使用情况（CPU、内存）
- 检查网络延迟
- 检查 Fluentd buffer 是否积压
- 检查 OpenSearch 集群健康状态

### Buffer 溢出

如果 Fluent Bit buffer 接近 50MB 限制：
- 降低 QPS
- 检查 Fluentd 处理速度
- 检查网络连接

## 参考资源

- [k6 官方文档](https://k6.io/docs/)
- [k6 性能测试最佳实践](https://k6.io/docs/test-authoring/best-practices/)
- [k6 场景执行器](https://k6.io/docs/using-k6/scenarios/executors/)
