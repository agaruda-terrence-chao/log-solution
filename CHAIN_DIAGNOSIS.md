# 日志链路诊断报告

## 链路检查：fastapi-app -> fluentd-aggregator -> opensearch -> opensearch-dashboards

### ✅ 正常工作的组件

1. **fastapi-app Pod**
   - ✅ Pod 正常运行 (Running)
   - ✅ 日志输出到 stdout/stderr 正常
   - ⚠️ **问题**: 日志没有被发送到 fluentd-aggregator

2. **fluentd-aggregator**
   - ✅ Pod 正常运行 (2个副本)
   - ✅ 正在监听 forward 端口 (24224)
   - ✅ 正在监听 HTTP 端口 (9880)
   - ✅ 配置已更新为使用 OpenSearch Service (HTTP 9200)

3. **opensearch**
   - ✅ Service: `opensearch-cluster-master.opensearch.svc.cluster.local:9200` (HTTP)
   - ✅ Ingress: `opensearch.internal.agaruda.io:443` (HTTPS)
   - ✅ 集群状态: green
   - ✅ 可以从 log-solution namespace 连接

### ❌ 问题环节

#### 问题 1: fastapi-app 日志收集
**状态**: ⚠️ 日志没有被收集

**原因**: 
- K8S Pod 的日志默认只输出到 stdout/stderr
- 这些日志存储在 Node 的 `/var/log/containers/` 目录
- 需要 Fluentd DaemonSet Agent 或 sidecar 来收集并转发

**当前尝试**: 
- 已添加 fluent-bit sidecar，但遇到 `Too many open files` 错误
- 这是因为 sidecar 需要监控整个 `/var/log/containers/` 目录

**解决方案** (推荐):

**选项 A: 部署 Fluentd DaemonSet Agent (推荐)**
```bash
# 在每个 Node 上运行 Fluentd Agent，收集该 Node 上所有 Pod 的日志
# 这是 K8S 中日志收集的标准做法
# Agent 会读取 /var/log/containers/*.log 并转发到 fluentd-aggregator
```

**选项 B: 移除 sidecar，使用简单方案**
```bash
# 如果暂时不需要日志收集，可以禁用 fluent-bit sidecar
# 在 values.yaml 中设置: fluentd.enabled: false
```

**选项 C: 修复 fluent-bit sidecar (当前尝试中)**
- 需要更精确的文件监控配置
- 或者使用不同的日志收集方式

#### 问题 2: fluentd-aggregator 到 opensearch 连接
**状态**: ✅ 已修复

**修复内容**:
- 更新配置为使用 OpenSearch Service (`opensearch-cluster-master.opensearch.svc.cluster.local:9200`)
- 从 Ingress (HTTPS 443) 改为 Service (HTTP 9200)
- 更稳定、更快速（内部网络）

**配置位置**: `charts/fluentd-aggregator/values.yaml`
```yaml
opensearch:
  useService: true  # 使用 Service 而不是 Ingress
  service:
    name: opensearch-cluster-master
    namespace: opensearch
    port: 9200
```

### 验证步骤

1. **检查 fastapi-app 日志**
```bash
kubectl logs -n log-solution -l app.kubernetes.io/name=fastapi-app -c fastapi-app --tail=10
```

2. **检查 fluentd-aggregator 是否接收到日志**
```bash
kubectl logs -n log-solution -l app.kubernetes.io/name=fluentd-aggregator --tail=50 | grep -i "fastapi"
```

3. **检查 opensearch 索引**
```bash
kubectl run -it --rm test --image=curlimages/curl --restart=Never -n log-solution -- \
  curl -s http://opensearch-cluster-master.opensearch.svc.cluster.local:9200/_cat/indices?v | grep -E "fastapi|system"
```

4. **在 OpenSearch Dashboards 查看**
- 访问: https://opensearch-dashboards.internal.agaruda.io/
- 创建 Index Pattern: `fastapi-logs-*` 或 `system-metrics-*`

### 下一步行动

1. **修复日志收集问题**:
   - 如果使用 DaemonSet Agent: 部署 Fluentd DaemonSet
   - 如果使用 sidecar: 修复 fluent-bit 配置或移除 sidecar

2. **验证完整链路**:
   - 发送测试请求到 fastapi-app
   - 确认日志到达 fluentd-aggregator
   - 确认数据写入 opensearch
   - 在 dashboard 中查看数据

3. **监控和告警**:
   - 设置 OpenSearch Dashboards 监控
   - 配置错误日志告警

