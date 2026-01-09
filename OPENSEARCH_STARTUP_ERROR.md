# OpenSearch 啟動錯誤診斷與解決方案

## 問題描述

在進行壓力測試時，停止 OpenSearch 服務導致 Fluentd 累積了大量日誌。重新啟動 OpenSearch 時無法正常啟動，OpenSearch Dashboards 無法連接到 OpenSearch。

## 錯誤現象

### 日誌輸出

```
log-solution-fluentd-opensearch             | [2026-01-09T15:09:37,036][INFO ][o.o.p.PluginsService     ] [ca2be1f869e8] loaded plugin [opensearch-sql]
log-solution-fluentd-opensearch             | [2026-01-09T15:09:37,104][INFO ][o.o.e.ExtensionsManager  ] [ca2be1f869e8] ExtensionsManager initialized
log-solution-fluentd-opensearch             | [2026-01-09T15:09:37,149][INFO ][o.o.e.NodeEnvironment    ] [ca2be1f869e8] using [1] data paths, mounts [[/ (overlay)]], net usable_space [10gb], net total_space [58.3gb], types [overlay]
log-solution-fluentd-opensearch             | [2026-01-09T15:09:37,149][INFO ][o.o.e.NodeEnvironment    ] [ca2be1f869e8] heap size [1gb], compressed ordinary object pointers [true]
log-solution-fluentd-opensearch             | [2026-01-09T15:09:37,301][INFO ][o.o.n.Node               ] [ca2be1f869e8] node name [ca2be1f869e8], node ID [ZnrKt1KCQ1q60_Bb5POAlQ], cluster name [docker-cluster], roles [ingest, remote_cluster_client, data, cluster_manager]
log-solution-fluentd-opensearch-dashboards  | {"type":"log","@timestamp":"2026-01-09T15:09:37Z","tags":["error","opensearch","data"],"pid":1,"message":"[ConnectionError]: connect ECONNREFUSED 172.20.0.2:9200"}
log-solution-fluentd-opensearch             | [2026-01-09T15:09:39,450][DEPRECATION][o.o.d.c.s.Settings       ] [ca2be1f869e8] [index.store.hybrid.mmap.extensions] setting was deprecated in OpenSearch and will be removed in a future release! See the breaking changes documentation for the next major version.
log-solution-fluentd-opensearch-dashboards  | {"type":"log","@timestamp":"2026-01-09T15:09:40Z","tags":["error","opensearch","data"],"pid":1,"message":"[ConnectionError]: connect ECONNREFUSED 172.20.0.2:9200"}
```

### 關鍵錯誤信息

- **OpenSearch Dashboards 連接錯誤**: `ECONNREFUSED 172.20.0.2:9200`
- **OpenSearch 啟動狀態**: 正在初始化，但未完全啟動
- **堆內存配置**: 1GB（默認值）

## 問題原因分析

### 主要原因

1. **大量待處理數據**
   - Fluentd 在 OpenSearch 停止期間累積了大量日誌在 buffer 中
   - 重新啟動時，OpenSearch 需要處理大量待寫入的數據
   - 數據恢復和索引重建需要較長時間

2. **資源不足**
   - 默認 1GB 堆內存可能不足以處理大量數據
   - 磁盤空間可能不足
   - 啟動時間超過健康檢查的超時時間

3. **啟動超時**
   - Docker Compose healthcheck 的 `start_period` 設置為 60 秒
   - 大量數據恢復可能需要更長時間
   - 健康檢查在 OpenSearch 完全啟動前就判定失敗

4. **數據恢復問題**
   - OpenSearch 需要恢復未完成的寫入操作
   - 索引分片可能處於恢復狀態
   - 集群狀態可能為 `yellow` 或 `red`

## 診斷步驟

### 1. 檢查 OpenSearch 容器狀態

```bash
# 查看容器狀態
docker ps -a | grep opensearch

# 查看容器詳細信息
docker inspect log-solution-fluentd-opensearch | grep -A 10 "State"
```

### 2. 查看完整日誌

```bash
# 查看 OpenSearch 完整日誌
docker logs log-solution-fluentd-opensearch --tail 100 -f

# 查找錯誤信息
docker logs log-solution-fluentd-opensearch 2>&1 | grep -i "error\|exception\|fatal\|outofmemory"

# 查看啟動過程
docker logs log-solution-fluentd-opensearch 2>&1 | grep -i "started\|ready\|cluster"
```

### 3. 檢查資源使用情況

```bash
# 檢查容器資源使用
docker stats log-solution-fluentd-opensearch --no-stream

# 檢查系統磁盤空間
df -h

# 檢查 OpenSearch 數據目錄大小
docker exec log-solution-fluentd-opensearch du -sh /usr/share/opensearch/data 2>/dev/null || echo "容器未運行"
```

### 4. 檢查 Fluentd Buffer 大小

```bash
# 檢查 Fluentd buffer 目錄大小
du -sh playground/log-solution/fluentd/buffers/

# 查看 buffer 文件數量
find playground/log-solution/fluentd/buffers/ -type f | wc -l

# 查看 buffer 文件詳情
ls -lh playground/log-solution/fluentd/buffers/*/
```

### 5. 檢查 OpenSearch 健康狀態

```bash
# 檢查集群健康狀態
curl -s http://localhost:9200/_cluster/health?pretty

# 檢查集群統計信息
curl -s http://localhost:9200/_cluster/stats?pretty

# 檢查節點信息
curl -s http://localhost:9200/_nodes?pretty

# 檢查索引狀態
curl -s http://localhost:9200/_cat/indices?v
```

### 6. 完整診斷腳本

```bash
#!/bin/bash
echo "=== OpenSearch 容器狀態 ==="
docker ps -a | grep opensearch

echo -e "\n=== OpenSearch 日誌（最後 50 行）==="
docker logs log-solution-fluentd-opensearch --tail 50

echo -e "\n=== OpenSearch 資源使用 ==="
docker stats log-solution-fluentd-opensearch --no-stream

echo -e "\n=== 磁盤空間 ==="
df -h | grep -E "Filesystem|/$"

echo -e "\n=== Fluentd Buffer 大小 ==="
du -sh playground/log-solution/fluentd/buffers/ 2>/dev/null || echo "目錄不存在"

echo -e "\n=== OpenSearch 健康檢查 ==="
curl -s http://localhost:9200/_cluster/health?pretty || echo "OpenSearch 未響應"

echo -e "\n=== OpenSearch 索引列表 ==="
curl -s http://localhost:9200/_cat/indices?v || echo "無法獲取索引列表"
```

## 解決方案

### 方案 1: 增加 OpenSearch 啟動等待時間（推薦用於數據重要場景）

如果數據重要，可以增加健康檢查的等待時間，給 OpenSearch 更多時間恢復數據。

**修改 `docker-compose-fluentd-2.yaml`:**

```yaml
opensearch:
  image: opensearchproject/opensearch:2.11.0
  container_name: log-solution-fluentd-opensearch
  environment:
    - "discovery.type=single-node"
    - "DISABLE_SECURITY_PLUGIN=true"
    - "DISABLE_INSTALL_DEMO_CONFIG=true"
    - "network.host=0.0.0.0"
  healthcheck:
    test: ["CMD-SHELL", "curl -f http://localhost:9200/_cluster/health || exit 1"]
    interval: 30s      # 增加檢查間隔（從 10s 改為 30s）
    timeout: 10s       # 增加超時時間（從 5s 改為 10s）
    retries: 60        # 增加重試次數（從 30 改為 60，最多等待 30 分鐘）
    start_period: 300s # 增加啟動等待期（從 60s 改為 300s，5 分鐘）
```

**重新啟動服務:**

```bash
docker-compose -f docker-compose-fluentd-2.yaml up -d opensearch
```

### 方案 2: 增加 OpenSearch 內存配置

如果系統有足夠內存，可以增加 OpenSearch 的堆內存以加快處理速度。

**修改 `docker-compose-fluentd-2.yaml`:**

```yaml
opensearch:
  image: opensearchproject/opensearch:2.11.0
  container_name: log-solution-fluentd-opensearch
  environment:
    - "discovery.type=single-node"
    - "DISABLE_SECURITY_PLUGIN=true"
    - "DISABLE_INSTALL_DEMO_CONFIG=true"
    - "network.host=0.0.0.0"
    # 增加堆內存（根據系統可用內存調整，建議不超過系統內存的 50%）
    - "OPENSEARCH_JAVA_OPTS=-Xms2g -Xmx2g"
  # 添加資源限制（可選）
  deploy:
    resources:
      limits:
        memory: 4G
      reservations:
        memory: 2G
```

### 方案 3: 分批處理 Fluentd Buffer（推薦用於數據重要場景）

如果數據重要，可以分批處理，避免一次性寫入過多數據。

**步驟:**

```bash
# 1. 停止 Fluentd（防止繼續寫入 buffer）
docker stop log-solution-fluentd-2

# 2. 單獨啟動 OpenSearch（給它時間恢復）
docker start log-solution-fluentd-opensearch

# 3. 監控 OpenSearch 健康狀態
watch -n 5 'curl -s http://localhost:9200/_cluster/health?pretty'

# 4. 當 OpenSearch 健康狀態為 "green" 或 "yellow" 時，重新啟動 Fluentd
docker start log-solution-fluentd-2

# 5. 監控 Fluentd buffer 處理進度
watch -n 5 'du -sh playground/log-solution/fluentd/buffers/*/'
```

### 方案 4: 清理 Fluentd Buffer（僅用於測試數據）

**⚠️ 警告：此操作會丟失所有未寫入的日誌數據，僅適用於測試環境！**

```bash
# 1. 停止所有服務
docker-compose -f docker-compose-fluentd-2.yaml down

# 2. 清理 Fluentd buffer
rm -rf playground/log-solution/fluentd/buffers/*

# 3. 重新啟動服務
docker-compose -f docker-compose-fluentd-2.yaml up -d
```

### 方案 5: 重置 OpenSearch 數據（僅用於測試數據）

**⚠️ 警告：此操作會丟失所有 OpenSearch 中的數據，僅適用於測試環境！**

```bash
# 1. 停止所有服務
docker-compose -f docker-compose-fluentd-2.yaml down

# 2. 查找 OpenSearch 數據卷
docker volume ls | grep opensearch

# 3. 刪除 OpenSearch 數據卷（替換 <volume-name> 為實際卷名）
docker volume rm <volume-name>

# 或者如果使用 bind mount，刪除數據目錄
# rm -rf <opensearch-data-directory>

# 4. 重新啟動服務
docker-compose -f docker-compose-fluentd-2.yaml up -d
```

### 方案 6: 限制 Fluentd Buffer 大小（預防措施）

為避免未來再次出現此問題，可以限制 Fluentd buffer 的大小。

**修改 `fluentd/conf.d/service-fastapi-app-2.conf`:**

```ruby
<buffer>
  @type file
  path /fluentd/buffers/app_all.buffer
  flush_at_shutdown true
  flush_mode interval
  flush_interval 1s
  retry_forever true
  flush_thread_count 4
  chunk_full_threshold 0.8
  total_limit_size 512MB  # 限制總大小（從 1024MB 改為 512MB）
  chunk_limit_size 16MB   # 限制單個 chunk 大小（從 32MB 改為 16MB）
  queued_chunks_limit_size 4
  overflow_action block   # 改為 block，避免丟失數據但可能阻塞
  retry_type exponential_backoff
  compress_method gzip
</buffer>
```

## 預防措施

### 1. 監控 OpenSearch 健康狀態

定期檢查 OpenSearch 健康狀態：

```bash
# 設置定時任務監控
*/5 * * * * curl -s http://localhost:9200/_cluster/health?pretty | grep -q '"status":"green"' || echo "OpenSearch unhealthy" | mail -s "OpenSearch Alert" admin@example.com
```

### 2. 設置 Fluentd Buffer 告警

監控 Fluentd buffer 大小，超過閾值時告警：

```bash
# 檢查 buffer 大小的腳本
#!/bin/bash
BUFFER_SIZE=$(du -sm playground/log-solution/fluentd/buffers/ | cut -f1)
THRESHOLD=500  # 500MB

if [ "$BUFFER_SIZE" -gt "$THRESHOLD" ]; then
    echo "警告：Fluentd buffer 大小超過 ${THRESHOLD}MB，當前為 ${BUFFER_SIZE}MB"
    # 發送告警通知
fi
```

### 3. 定期清理舊索引

設置索引生命週期管理（ILM）或定期清理舊索引：

```bash
# 刪除 30 天前的索引
curl -X DELETE "http://localhost:9200/fastapi-logs-$(date -d '30 days ago' +%Y.%m.%d)"
curl -X DELETE "http://localhost:9200/fastapi-error-logs-$(date -d '30 days ago' +%Y.%m.%d)"
```

### 4. 壓力測試最佳實踐

進行壓力測試時：

1. **監控資源使用**: 持續監控 CPU、內存、磁盤使用率
2. **逐步增加負載**: 不要一次性產生大量日誌
3. **設置停止條件**: 當資源使用率超過閾值時自動停止測試
4. **測試後清理**: 測試完成後清理測試數據

## 相關文檔

- [README-FLUENTD.md](./README-FLUENTD.md) - Fluentd 配置說明
- [CHAIN_DIAGNOSIS.md](./CHAIN_DIAGNOSIS.md) - 鏈路診斷指南
- [OPENSEARCH_DASHBOARDS_SETUP.md](./OPENSEARCH_DASHBOARDS_SETUP.md) - OpenSearch Dashboards 設置

## 更新記錄

- **2026-01-09**: 初始版本，記錄 OpenSearch 啟動錯誤問題

