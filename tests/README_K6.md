# K6 压测脚本使用指南

## 概述

本目录包含使用 [k6](https://k6.io/) 对 FastAPI 应用进行压力测试的脚本。

## 脚本说明

### load_test_order_app.js

针对 Order App 的压力测试脚本，发送日志到 Fluent Bit HTTP input (端口 8888)。

**压测参数：**
- **QPS**: 1000 请求/秒
- **持续时间**: 5 分钟（可在脚本中调整）
- **预分配 VUs**: 100
- **最大 VUs**: 500
- **目标 URL**: `http://localhost:8888`

**测试数据：**
- 90% INFO 级别日志（订单创建成功）
- 10% ERROR 级别日志（支付失败）
- 包含字段：`message`, `level`, `order_id`, `user_id`, `amount`, `timestamp`

**性能阈值：**
- 95% 请求响应时间 < 200ms
- 99% 请求响应时间 < 500ms
- 错误率 < 1%
- 中位数响应时间 < 100ms
- Order 创建成功率 > 99%

### load_test_user_app.js

针对 User App 的压力测试脚本，发送日志到 Fluent Bit HTTP input (端口 8889)。

**压测参数：**
- **QPS**: 1000 请求/秒
- **持续时间**: 5 分钟（可在脚本中调整）
- **预分配 VUs**: 100
- **最大 VUs**: 500
- **目标 URL**: `http://localhost:8889`

**测试数据：**
- 90% INFO 级别日志（用户操作成功）
- 10% ERROR 级别日志（认证失败）
- 包含字段：`message`, `level`, `user_id`, `action`, `ip_address`, `timestamp`
- 用户操作类型：login, logout, register, profile_update, password_change, session_refresh

**性能阈值：**
- 95% 请求响应时间 < 200ms
- 99% 请求响应时间 < 500ms
- 错误率 < 1%
- 中位数响应时间 < 100ms
- 用户操作成功率 > 99%

### load_test_yolo.js

针对 `http://localhost:8000/test?query=yolo` 端点的压测脚本。

**压测参数：**
- **QPS**: 3000 请求/秒
- **持续时间**: 5 分钟（可在脚本中调整）
- **预分配 VUs**: 200
- **最大 VUs**: 1000

**性能阈值：**
- 95% 请求响应时间 < 500ms
- 99% 请求响应时间 < 1000ms
- 错误率 < 1%
- 中位数响应时间 < 200ms

## 安装 k6

### macOS
```bash
brew install k6
```

### Linux (Debian/Ubuntu)
```bash
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update
sudo apt-get install k6
```

### Docker
```bash
docker pull grafana/k6
```

## 使用方法

### 1. 确保服务运行

在运行压测前，确保 Fluent Bit 和 Fluentd 服务正在运行：

```bash
cd /Users/albert/Projects/Agaruda/playground/log-solution
docker-compose -f docker-compose-fluentd-3.yaml up -d fluent-bit-sidecar fluentd opensearch
```

### 2. 运行压测

#### Order App 压力测试

**本地运行：**
```bash
cd /Users/albert/Projects/Agaruda/playground/log-solution/tests
k6 run load_test_order_app.js
```

**使用 Docker 运行：**
```bash
cd /Users/albert/Projects/Agaruda/playground/log-solution/tests
docker run --rm -i -v $(pwd):/scripts -w /scripts --network host grafana/k6 run load_test_order_app.js
```

#### User App 压力测试

**本地运行：**
```bash
cd /Users/albert/Projects/Agaruda/playground/log-solution/tests
k6 run load_test_user_app.js
```

**使用 Docker 运行：**
```bash
cd /Users/albert/Projects/Agaruda/playground/log-solution/tests
docker run --rm -i -v $(pwd):/scripts -w /scripts --network host grafana/k6 run load_test_user_app.js
```

#### 同时运行两个服务的压力测试

```bash
# 终端 1: Order App
k6 run load_test_order_app.js

# 终端 2: User App
k6 run load_test_user_app.js
```

### 3. 自定义参数运行

**调整持续时间（例如：运行 2 分钟）：**
```bash
k6 run --duration 2m load_test_order_app.js
k6 run --duration 2m load_test_user_app.js
```

**调整 QPS（例如：QPS=500）：**
```bash
k6 run -e TARGET_QPS=500 load_test_order_app.js
k6 run -e TARGET_QPS=500 load_test_user_app.js
```

然后在脚本中使用环境变量：
```javascript
rate: parseInt(__ENV.TARGET_QPS) || 1000,
```

**输出结果到文件：**
```bash
k6 run --out json=results_order_app.json load_test_order_app.js
k6 run --out json=results_user_app.json load_test_user_app.js
```

**使用 InfluxDB 输出（用于 Grafana 可视化）：**
```bash
k6 run --out influxdb=http://localhost:8086/k6 load_test_order_app.js
```

## 输出说明

k6 会输出详细的压测报告，包括：

- **HTTP 请求统计**
  - 总请求数
  - 请求成功率
  - 响应时间分布（最小值、平均值、中位数、p95、p99、最大值）

- **自定义指标**
  - `errors`: 错误率
  - `response_time`: 响应时间趋势

- **性能阈值检查**
  - 是否满足设定的性能阈值

## 示例输出

```
          /\      |‾‾| /‾‾/   /‾‾/
     /\  /  \     |  |/  /   /  /
    /  \/    \    |     (   /   ‾‾\
   /          \   |  |\  \ |  (‾)  |
  / __________ \  |__| \__\ \_____/ .io

  execution: local
     script: load_test_yolo.js
     output: -

  scenarios: (100.00%) 1 scenario, 1000 max VUs, 5m30s max duration
           ✓ setup
           ✓ teardown

     ✓ status is 200
     ✓ response has status field
     ✓ response has message
     ✓ errors.........................: 0.00%  ✓ 0     ✗ 900000
     ✓ http_req_duration..............: avg=45.23ms min=12ms med=38ms max=234ms p(90)=89ms p(95)=156ms p(99)=198ms
     ✓ response_time..................: avg=45.23ms min=12ms med=38ms max=234ms

     checks.........................: 100.00% ✓ 2700000 ✗ 0
     data_received..................: 45 MB   136 kB/s
     data_sent......................: 23 MB   70 kB/s
     http_req_duration..............: avg=45.23ms min=12ms med=38ms max=234ms
     http_reqs......................: 900000  2727.27/s
     iteration_duration.............: avg=45.23ms min=12ms med=38ms max=234ms
     iterations.....................: 900000  2727.27/s
     vus............................: 200     min=200 max=200
     vus_max........................: 1000    min=1000 max=1000
```

## 监控建议

在压测期间，建议监控：

1. **Fluent Bit 服务性能**
   ```bash
   docker stats log-solution-fluentd-3-fluent-bit-sidecar
   docker logs -f log-solution-fluentd-3-fluent-bit-sidecar
   ```

2. **Fluentd 处理能力**
   ```bash
   docker stats log-solution-fluentd-3
   docker logs -f log-solution-fluentd-3
   ```

3. **OpenSearch 索引写入**
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

4. **Fluent Bit Buffer 使用情况**
   ```bash
   # 检查 buffer 目录大小
   du -sh playground/log-solution/fluent-bit-sidecar/flb-storage/
   ```

5. **系统资源**
   ```bash
   # CPU 和内存使用
   top
   # 或
   htop
   ```

## 注意事项

1. **QPS 调整**: 如果目标 QPS 过高导致大量请求失败，可以逐步降低 QPS 或增加服务资源
2. **持续时间**: 长时间压测可能会产生大量日志，注意 OpenSearch 存储空间
3. **网络**: 确保本地网络能够处理 1000+ QPS 的流量
4. **资源限制**: 监控 CPU、内存和磁盘 I/O，避免系统过载
5. **Buffer 限制**: Fluent Bit 配置了 50MB 的文件系统 buffer，注意监控 buffer 使用情况
6. **并发测试**: 可以同时运行 Order App 和 User App 的压力测试，模拟真实场景

## 故障排除

### 错误：连接被拒绝
- 确保 FastAPI 服务正在运行
- 检查端口 8000 是否被占用
- 检查防火墙设置

### 错误率过高
- 降低 QPS
- 增加服务的资源限制
- 检查 Fluentd 和 OpenSearch 是否正常工作

### 响应时间过长
- 检查服务资源使用情况
- 优化 FastAPI 应用性能
- 检查 Fluentd 日志处理是否成为瓶颈

## 参考资源

- [k6 官方文档](https://k6.io/docs/)
- [k6 性能测试最佳实践](https://k6.io/docs/test-authoring/best-practices/)
- [k6 场景执行器](https://k6.io/docs/using-k6/scenarios/executors/)

