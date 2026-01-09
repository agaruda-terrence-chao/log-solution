# FastAPI -> Fluentd -> OpenSearch 工作流程

## 概述

這個工作流程實現了 `fastapi-app -> fluentd -> opensearch` 的日誌收集和存儲架構。

## 架構圖

```
┌─────────────┐
│ fastapi-app │ (Docker logging driver: fluentd)
└──────┬──────┘
       │ 日誌流 (Fluentd Forward Protocol)
       ▼
┌─────────────┐
│   Fluentd   │ (日誌收集、過濾、轉換)
└──────┬──────┘
       │ 處理後的日誌
       ▼
┌─────────────┐
│ OpenSearch  │ (日誌存儲與搜索)
└──────┬──────┘
       │
       ▼
┌─────────────────────┐
│ OpenSearch          │
│ Dashboards          │ (日誌可視化)
└─────────────────────┘
```

## 快速開始

### 1. 啟動服務

```bash
docker-compose -f docker-compose-fluentd.yaml up -d
```

### 2. 等待服務就緒

```bash
# 檢查服務狀態
docker-compose -f docker-compose-fluentd.yaml ps

# 查看日誌
docker-compose -f docker-compose-fluentd.yaml logs -f
```

### 3. 發送測試請求

```bash
# 成功日誌
curl "http://localhost:8000/test?query=yolo"

# 錯誤日誌
curl "http://localhost:8000/test?query=invalid"
```

### 4. 查看日誌

#### 在 OpenSearch 中查詢

```bash
# 查看索引
curl "http://localhost:9200/_cat/indices/fastapi-logs-*?v"

# 查看日誌數量
curl "http://localhost:9200/fastapi-logs-*/_count" | jq

# 查看最近的日誌
curl "http://localhost:9200/fastapi-logs-*/_search?size=5&sort=@timestamp:desc" | jq
```

#### 在 OpenSearch Dashboards 中查看

1. 訪問 http://localhost:5601
2. 創建索引模式：`fastapi-logs-*`
3. 時間字段選擇：`@timestamp`
4. 開始探索日誌

## 服務說明

### fastapi-app

- **端口**: 8000
- **日誌驅動**: Fluentd
- **標籤**: `fastapi.app`
- **功能**: 提供測試 API，根據 query 參數記錄成功或錯誤日誌

### fluentd

- **端口**: 24224 (Forward Protocol)
- **配置**: `./fluentd/conf/fluent.conf`
- **功能**:
  - 接收 FastAPI 日誌
  - 解析和轉換日誌內容
  - 識別日誌類型（success/error/info）
  - 分類錯誤類型（validation_error/general_error）
  - 輸出到 OpenSearch

### opensearch

- **端口**: 9200
- **功能**: 存儲和索引日誌數據

### opensearch-dashboards

- **端口**: 5601 (僅本地訪問)
- **功能**: 可視化和分析日誌

## 日誌字段說明

Fluentd 會為每條日誌添加以下字段：

- `service_name`: "fastapi-app"
- `log_source`: "fluentd"
- `log_type`: "success" | "error" | "info"
- `log_level`: "ERROR" | "INFO"
- `is_error`: true | false
- `error_category`: "validation_error" | "general_error" | ""
- `@timestamp`: ISO 8601 時間戳
- `@log_name`: 原始標籤 (fastapi.app)

## 測試腳本

使用提供的測試腳本自動化測試：

```bash
./test_fluentd_workflow.sh
```

## 故障排查

### 檢查 Fluentd 連接

```bash
# 查看 Fluentd 日誌
docker-compose -f docker-compose-fluentd.yaml logs fluentd

# 檢查端口
docker-compose -f docker-compose-fluentd.yaml exec fluentd nc -z localhost 24224
```

### 檢查 OpenSearch 連接

```bash
# 查看 OpenSearch 日誌
docker-compose -f docker-compose-fluentd.yaml logs opensearch

# 檢查健康狀態
curl "http://localhost:9200/_cluster/health"
```

### 檢查日誌流

```bash
# 查看 FastAPI 容器日誌
docker-compose -f docker-compose-fluentd.yaml logs fastapi-app

# 查看 Fluentd 處理的日誌
docker-compose -f docker-compose-fluentd.yaml logs fluentd | grep "fastapi.app"
```

## 配置自定義

### 修改 Fluentd 配置

編輯 `./fluentd/conf/fluent-opensearch.conf`，然後：

```bash
cp fluentd/conf/fluent-opensearch.conf fluentd/conf/fluent.conf
docker-compose -f docker-compose-fluentd.yaml restart fluentd
```

### 修改索引名稱

在 `fluentd/conf/fluent-opensearch.conf` 中修改：

```xml
logstash_prefix your-custom-prefix
```

## 停止服務

```bash
docker-compose -f docker-compose-fluentd.yaml down
```

## 清理數據

```bash
# 停止並刪除容器
docker-compose -f docker-compose-fluentd.yaml down -v

# 刪除 OpenSearch 索引
curl -X DELETE "http://localhost:9200/fastapi-logs-*"
```

