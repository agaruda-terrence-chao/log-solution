# OpenSearch Dashboards Index Pattern 設置指南

## 根據 Fluentd 配置的索引命名規則

根據 `fluentd/conf/fluent-opensearch.conf` 配置：

```xml
logstash_format true
logstash_dateformat %Y.%m.%d
logstash_prefix fastapi-logs
```

**索引命名格式**：`fastapi-logs-YYYY.MM.DD`

例如：
- `fastapi-logs-2026.01.07`
- `fastapi-logs-2026.01.08`
- `fastapi-logs-2026.01.09`

## 在 OpenSearch Dashboards 中創建 Index Pattern

### 步驟 1：訪問 OpenSearch Dashboards

1. 打開瀏覽器，訪問：http://localhost:5601
2. 等待 OpenSearch Dashboards 完全加載

### 步驟 2：創建 Index Pattern

1. **進入 Index Patterns 頁面**
   - 點擊左側導航欄的 **"Stack Management"**（或 **"Management"**）
   - 選擇 **"Index Patterns"**
   - 點擊 **"Create index pattern"** 按鈕

2. **設置 Index Pattern 名稱**
   - 在 **"Index pattern name"** 輸入框中輸入：
     ```
     fastapi-logs-*
     ```
   - 點擊 **"Next step"**

3. **選擇時間字段**
   - 在 **"Time field"** 下拉菜單中選擇：
     ```
     @timestamp
     ```
   - 這是 logstash_format 自動添加的時間戳字段
   - 點擊 **"Create index pattern"**

### 步驟 3：驗證 Index Pattern

1. 確認索引模式已創建
2. 檢查是否能看到索引列表（例如：`fastapi-logs-2026.01.07`）
3. 確認字段列表包含以下字段：
   - `@timestamp` - 時間戳
   - `service_name` - 服務名稱（"fastapi-app"）
   - `log_source` - 日誌來源（"fluentd"）
   - `log_type` - 日誌類型（"success" | "error" | "info"）
   - `log_level` - 日誌級別（"ERROR" | "INFO"）
   - `is_error` - 是否為錯誤（true | false）
   - `error_category` - 錯誤分類（"validation_error" | "general_error" | ""）
   - `log` - 原始日誌內容
   - `@log_name` - 標籤名稱（"fastapi.app"）

## 查看日誌

### 在 Discover 中查看

1. 點擊左側導航欄的 **"Discover"**
2. 在右上角選擇 **"fastapi-logs-*"** index pattern
3. 選擇時間範圍（例如：Last 15 minutes）
4. 點擊 **"Refresh"** 查看日誌

### 常用查詢示例

#### 查看所有錯誤日誌
```
is_error: true
```

#### 查看驗證錯誤
```
error_category: validation_error
```

#### 查看成功日誌
```
log_type: success
```

#### 查看特定服務的日誌
```
service_name: fastapi-app
```

#### 組合查詢（錯誤且包含 "Invalid"）
```
is_error: true AND log: "Invalid"
```

## 字段說明

| 字段名 | 類型 | 說明 |
|--------|------|------|
| `@timestamp` | date | 日誌時間戳（ISO 8601） |
| `service_name` | keyword | 服務名稱，固定為 "fastapi-app" |
| `log_source` | keyword | 日誌來源，固定為 "fluentd" |
| `log_type` | keyword | 日誌類型：success / error / info |
| `log_level` | keyword | 日誌級別：ERROR / INFO |
| `is_error` | boolean | 是否為錯誤日誌 |
| `error_category` | keyword | 錯誤分類：validation_error / general_error / "" |
| `log` | text | 原始日誌內容 |
| `@log_name` | keyword | Fluentd 標籤：fastapi.app |
| `timestamp` | keyword | Fluentd 添加的時間戳 |

## 故障排查

### 問題：找不到索引

**檢查索引是否存在**：
```bash
curl "http://localhost:9200/_cat/indices/fastapi-logs-*?v"
```

**檢查 Fluentd 是否正常運行**：
```bash
docker-compose -f docker-compose-fluentd.yaml logs fluentd
```

**確認日誌已發送**：
```bash
# 發送測試請求
curl "http://localhost:8000/test?query=yolo"

# 等待幾秒後檢查索引
curl "http://localhost:9200/fastapi-logs-*/_count" | jq
```

### 問題：時間字段不正確

如果 `@timestamp` 字段不存在，可以嘗試：
- `timestamp` - Fluentd 添加的字段
- `time` - 原始時間字段

### 問題：字段類型不正確

如果字段類型顯示不正確，可以：
1. 刪除現有的 index pattern
2. 重新創建 index pattern
3. OpenSearch 會根據實際數據自動推斷字段類型

## 進階配置

### 自定義字段映射

如果需要修改字段映射，可以在 OpenSearch 中直接更新：

```bash
# 查看當前映射
curl "http://localhost:9200/fastapi-logs-*/_mapping" | jq

# 更新映射（示例：將 log 字段設為 keyword）
curl -X PUT "http://localhost:9200/fastapi-logs-*/_mapping" -H 'Content-Type: application/json' -d'
{
  "properties": {
    "log": {
      "type": "keyword"
    }
  }
}'
```

### 修改索引命名規則

如果需要修改索引命名，編輯 `fluentd/conf/fluent-opensearch.conf`：

```xml
<match fastapi.app>
  @type opensearch
  ...
  logstash_prefix your-custom-prefix  <!-- 修改這裡 -->
  ...
</match>
```

然後重啟 Fluentd：
```bash
docker-compose -f docker-compose-fluentd.yaml restart fluentd
```

