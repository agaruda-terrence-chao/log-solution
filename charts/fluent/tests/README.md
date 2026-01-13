# Kubernetes 环境压力测试指南（Port-Forward 方式）

本目录包含针对 Kubernetes 环境中 Fluent Bit HTTP input 的 K6 压力测试脚本。**推荐使用 Port-Forward 方式在本地运行测试**，这样可以更方便地监控和调试。

## 测试脚本

- `load_test_order_app_k8s.js` - Order App 压力测试
- `load_test_user_app_k8s.js` - User App 压力测试
- `setup_port_forward.sh` - 自动设置 Port-Forward 脚本
- `cleanup_port_forward.sh` - 清理 Port-Forward 进程脚本
- `run_load_test.sh` - 快速运行测试脚本

## 前置条件

1. **K6 已安装**
   ```bash
   # macOS
   brew install k6
   
   # Linux
   sudo gpg -k
   sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
   echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
   sudo apt-get update
   sudo apt-get install k6
   ```

2. **Kubernetes 集群中 Fluent Bit 和 Fluentd 已部署**
   ```bash
   kubectl get pods -n fluent
   ```

3. **kubectl 已配置并可以访问集群**
   ```bash
   kubectl cluster-info
   ```

## 快速开始（推荐：Port-Forward 方式）

### 步骤 1: 设置 Port-Forward

使用提供的脚本自动设置所有需要的 port-forward：

```bash
cd playground/log-solution/charts/fluent/tests
./setup_port_forward.sh
```

脚本会自动设置：
- Order App 端口: `localhost:8888`
- User App 端口: `localhost:8889`
- OpenSearch 端口: `localhost:9200`（可选）

**手动设置方式**（如果脚本不可用）：

```bash
# 终端 1: Fluent Bit Order App 端口
kubectl port-forward -n fluent svc/fluent-fluent-bit 8888:8888

# 终端 2: Fluent Bit User App 端口
kubectl port-forward -n fluent svc/fluent-fluent-bit 8889:8889

# 终端 3: OpenSearch 端口（可选，用于验证）
kubectl port-forward -n opensearch svc/opensearch-cluster-master 9200:9200
```

### 步骤 2: 运行压力测试

#### 方式 A: 使用快速运行脚本（推荐）

```bash
# Order App 压力测试
./run_load_test.sh order

# User App 压力测试
./run_load_test.sh user

# 自定义参数
TARGET_QPS=5000 DURATION=60s ./run_load_test.sh order
```

#### 方式 B: 直接使用 K6 命令

```bash
# Order App 测试（默认使用 localhost）
k6 run \
  -e TARGET_QPS=1000 \
  -e DURATION=30s \
  load_test_order_app_k8s.js

# User App 测试
k6 run \
  -e TARGET_QPS=1000 \
  -e DURATION=30s \
  load_test_user_app_k8s.js
```

### 步骤 3: 清理 Port-Forward

测试完成后，清理所有 port-forward 进程：

```bash
./cleanup_port_forward.sh
```

或者手动停止：

```bash
# 查找并停止所有 kubectl port-forward 进程
pkill -f "kubectl port-forward"
```

## 详细使用说明

### 环境变量配置

测试脚本支持以下环境变量（默认值已针对 port-forward 优化）：

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `FLUENT_BIT_SERVICE` | `localhost` | Fluent Bit Service 地址（port-forward 使用 localhost） |
| `FLUENT_BIT_ORDER_PORT` | `8888` | Order App 端口 |
| `FLUENT_BIT_USER_PORT` | `8889` | User App 端口 |
| `OPENSEARCH_SERVICE` | `localhost` | OpenSearch Service 地址（port-forward 使用 localhost） |
| `OPENSEARCH_PORT` | `9200` | OpenSearch 端口 |
| `TARGET_QPS` | `1000` | 目标 QPS（每秒请求数） |
| `DURATION` | `30s` | 测试持续时间 |

### 测试参数调整

#### 调整 QPS 和持续时间

```bash
# 高负载测试：5000 QPS，持续 60 秒
k6 run \
  -e TARGET_QPS=5000 \
  -e DURATION=60s \
  load_test_order_app_k8s.js

# 低负载测试：100 QPS，持续 10 秒
k6 run \
  -e TARGET_QPS=100 \
  -e DURATION=10s \
  load_test_order_app_k8s.js
```

#### 调整虚拟用户数

编辑测试脚本中的以下参数：

```javascript
preAllocatedVUs: 100,  // 预分配的虚拟用户数（建议设置为 QPS 的 10-20%）
maxVUs: 500,            // 最大虚拟用户数（当请求积压时自动增加）
```

### 性能阈值

测试脚本中定义了以下性能阈值：

- **响应时间**: 95% 的请求应该在 200ms 内完成，99% 应该在 500ms 内
- **错误率**: 应该小于 1%
- **业务成功率**: Order/User 操作成功率应该大于 99%

如果测试结果不满足这些阈值，K6 会标记测试为失败。

## 结果验证

### 查看测试结果

测试完成后，K6 会输出详细的性能指标：

```
✓ status is 200 or 201
✓ response received
checks.........................: 100.00% ✓ 30000    ✗ 0
data_received..................: 4.5 MB  150 kB/s
data_sent......................: 8.1 MB  270 kB/s
http_req_duration..............: avg=45ms  min=12ms  med=38ms  max=234ms  p(90)=89ms  p(95)=123ms  p(99)=189ms
http_reqs......................: 30000   1000.123456/s
iteration_duration.............: avg=45ms  min=12ms  med=38ms  max=234ms
vus............................: 100     min=100    max=500
```

### 验证 OpenSearch 中的日志

#### 使用 Port-Forward 查询（本地）

如果已设置 OpenSearch port-forward：

```bash
# 查询 Order App 正常日志数量
curl -s "http://localhost:9200/order-logs-*/_count?q=service_name:order-app" | jq

# 查询 Order App 错误日志数量
curl -s "http://localhost:9200/order-error-logs-*/_count?q=service_name:order-app" | jq

# 查询最近的日志
curl -s "http://localhost:9200/order-logs-*/_search?q=service_name:order-app&size=5&sort=@timestamp:desc&pretty" | jq
```

#### 在 Kubernetes 集群内查询

```bash
# 查询 Order App 正常日志数量
kubectl run -it --rm test-opensearch-$(date +%s) \
  --image=curlimages/curl:latest \
  --restart=Never \
  -n fluent \
  -- curl -s "http://opensearch-cluster-master.opensearch.svc.cluster.local:9200/order-logs-*/_count?q=service_name:order-app"

# 查询 User App 正常日志数量
kubectl run -it --rm test-opensearch-$(date +%s) \
  --image=curlimages/curl:latest \
  --restart=Never \
  -n fluent \
  -- curl -s "http://opensearch-cluster-master.opensearch.svc.cluster.local:9200/user-logs-*/_count?q=service_name:user-app"
```

## 故障排查

### Port-Forward 连接失败

1. **检查 Service 是否存在**
   ```bash
   kubectl get svc -n fluent fluent-fluent-bit
   ```

2. **检查 Pod 是否运行**
   ```bash
   kubectl get pods -n fluent -l app.kubernetes.io/component=fluent-bit
   ```

3. **检查端口是否被占用**
   ```bash
   # macOS/Linux
   lsof -i :8888
   lsof -i :8889
   ```

4. **检查 Port-Forward 进程**
   ```bash
   ps aux | grep "kubectl port-forward"
   ```

### 测试无法连接到 Fluent Bit

1. **确认 Port-Forward 正在运行**
   ```bash
   # 测试连接
   curl -X POST http://localhost:8888 \
     -H "Content-Type: application/json" \
     -d '{"message":"test","level":"INFO"}'
   ```

2. **检查 Fluent Bit Pod 日志**
   ```bash
   kubectl logs -n fluent -l app.kubernetes.io/component=fluent-bit --tail=50
   ```

3. **检查 Service Endpoints**
   ```bash
   kubectl get endpoints -n fluent fluent-fluent-bit
   ```

### 测试超时或失败率高

1. **降低 QPS**
   ```bash
   k6 run -e TARGET_QPS=500 load_test_order_app_k8s.js
   ```

2. **增加超时时间**
   编辑测试脚本中的 `timeout: '10s'` 参数

3. **检查 Fluent Bit Pod 资源限制**
   ```bash
   kubectl describe pod -n fluent -l app.kubernetes.io/component=fluent-bit | grep -A 5 "Limits"
   ```

4. **检查 Fluent Bit Pod CPU/内存使用**
   ```bash
   kubectl top pods -n fluent -l app.kubernetes.io/component=fluent-bit
   ```

### 日志未出现在 OpenSearch

1. **检查 Fluentd Pod 状态**
   ```bash
   kubectl get pods -n fluent -l app.kubernetes.io/component=fluentd
   kubectl logs -n fluent -l app.kubernetes.io/component=fluentd --tail=100
   ```

2. **检查 OpenSearch 连接**
   ```bash
   # 使用 port-forward
   curl -s "http://localhost:9200/_cluster/health?pretty"
   
   # 或在集群内
   kubectl run -it --rm test-$(date +%s) \
     --image=curlimages/curl:latest \
     --restart=Never \
     -n fluent \
     -- curl -s "http://opensearch-cluster-master.opensearch.svc.cluster.local:9200/_cluster/health?pretty"
   ```

3. **检查 Fluentd 配置**
   ```bash
   kubectl get configmap -n fluent fluent-fluentd-config -o yaml
   ```

## 其他运行方式

### 方式 1: 在 Kubernetes Pod 中运行

如果需要直接在 Kubernetes Pod 中运行（不使用 port-forward），需要设置环境变量：

```bash
k6 run \
  -e FLUENT_BIT_SERVICE=fluent-fluent-bit.fluent.svc.cluster.local \
  -e OPENSEARCH_SERVICE=opensearch-cluster-master.opensearch.svc.cluster.local \
  -e TARGET_QPS=1000 \
  -e DURATION=30s \
  load_test_order_app_k8s.js
```

**注意**: 这种方式需要在 Kubernetes Pod 内运行 K6，可以使用：

```bash
kubectl run k6-test-$(date +%s) \
  --image=grafana/k6:latest \
  --restart=Never \
  -n fluent \
  --rm -i \
  -- k6 run \
    -e FLUENT_BIT_SERVICE=fluent-fluent-bit.fluent.svc.cluster.local \
    -e OPENSEARCH_SERVICE=opensearch-cluster-master.opensearch.svc.cluster.local \
    -e TARGET_QPS=1000 \
    -e DURATION=30s \
    - <load_test_order_app_k8s.js
```

### 方式 2: 使用 Kubernetes Job（CI/CD）

创建 Job YAML 文件用于 CI/CD 流水线（参考 `../DEPLOYMENT_GUIDE.md`）。

## 最佳实践

1. **逐步增加负载**: 从低 QPS 开始，逐步增加到目标值
2. **监控资源使用**: 测试时监控 Fluent Bit 和 Fluentd Pod 的 CPU/内存使用
3. **验证日志完整性**: 测试后验证 OpenSearch 中的日志数量是否与发送的请求数匹配
4. **清理资源**: 测试完成后及时清理 port-forward 进程
5. **保存测试结果**: 使用 K6 的 `--out` 参数保存测试结果到文件

```bash
k6 run --out json=results.json load_test_order_app_k8s.js
```

## 参考

- K6 官方文档: https://k6.io/docs/
- Docker Compose 环境测试脚本: `../../tests/load_test_order_app.js`, `../../tests/load_test_user_app.js`
- Kubernetes 测试指南: `../TESTING_GUIDE.md`
- Fluent Bit HTTP Input 格式: `../../FLUENT_BIT_HTTP_CURL_FORMAT.md`
- 部署指南: `../DEPLOYMENT_GUIDE.md`
