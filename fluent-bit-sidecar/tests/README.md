# Fluent Bit 測試

這個目錄包含 Fluent Bit 配置文件的測試。

## 測試結構

```
tests/
├── test_fluent_bit_config.rb      # 配置文件語法和結構驗證
└── test_fluent_bit_integration.rb # 集成測試（HTTP input 功能驗證）
```

## 測試內容

### 1. 配置文件測試 (`test_fluent_bit_config.rb`)

驗證 `fluent-bit.conf` 的語法和結構：
- ✅ 配置文件是否存在
- ✅ 配置文件語法驗證（使用 `fluent-bit --dry-run`）
- ✅ 必需的 sections 是否存在（SERVICE, INPUT, FILTER, OUTPUT）
- ✅ HTTP input 配置（端口 8888 和 8889）
- ✅ Filter 配置（Order App 和 User App）
- ✅ Storage 配置（文件系統 buffer，50MB 限制）
- ✅ Output 配置（forward 到 fluentd）

### 2. 集成測試 (`test_fluent_bit_integration.rb`)

通過 HTTP 發送數據並驗證 Fluent Bit 的處理：
- ✅ Order App HTTP input 可用性（端口 8888）
- ✅ User App HTTP input 可用性（端口 8889）
- ✅ Order App 正常日誌發送
- ✅ User App 正常日誌發送
- ✅ Order App 錯誤日誌發送
- ✅ User App 錯誤日誌發送
- ✅ 格式錯誤日誌處理

## 運行測試

### 方法 1: 使用 Makefile（推薦）

```bash
cd playground/log-solution/fluent-bit-sidecar/tests

# 運行所有測試
make test

# 運行特定測試
make test-config       # 只運行配置文件測試
make test-integration  # 只運行集成測試（需要服務運行）

# 服務管理
make check-service     # 檢查 Fluent Bit 服務狀態
make start-service     # 啟動 Fluent Bit 服務

# 查看幫助
make help
```

### 方法 2: 使用測試腳本

```bash
cd playground/log-solution/fluent-bit-sidecar/tests
chmod +x test.sh
./test.sh
```

### 方法 3: 直接運行 Ruby 測試

```bash
cd playground/log-solution/fluent-bit-sidecar/tests

# 運行配置文件測試
ruby test_fluent_bit_config.rb

# 運行集成測試（需要 Fluent Bit 服務運行）
ruby test_fluent_bit_integration.rb
```

### 方法 4: 使用 Docker Compose 環境

```bash
# 啟動 Fluent Bit 服務
cd playground/log-solution
docker-compose -f docker-compose-fluentd-3.yaml up -d fluent-bit-sidecar

# 運行集成測試
cd fluent-bit-sidecar/tests
make test-integration
# 或
ruby test_fluent_bit_integration.rb
```

## 前置條件

### 配置文件測試
- Ruby 環境（Ruby 2.7+）
- `test-unit` gem
- Fluent Bit 可執行文件（用於語法驗證）

### 集成測試
- Ruby 環境（Ruby 2.7+）
- `test-unit` gem
- Fluent Bit 服務運行在 `localhost:8888` 和 `localhost:8889`

## 注意事項

1. **集成測試需要服務運行**：集成測試需要 Fluent Bit 服務實際運行，否則會跳過測試
2. **Fluent Bit 可執行文件**：配置文件測試需要 `fluent-bit` 命令可用，可以通過環境變量 `FLUENT_BIT_BIN` 指定路徑
3. **網絡連接**：集成測試需要能夠連接到 `localhost:8888` 和 `localhost:8889`

## 故障排查

### 測試失敗

1. **Fluent Bit 命令不可用**：
   ```bash
   # 檢查 Fluent Bit 是否安裝
   which fluent-bit
   
   # 或指定路徑
   export FLUENT_BIT_BIN=/path/to/fluent-bit
   ```

2. **服務不可用**：
   ```bash
   # 檢查服務是否運行
   docker ps | grep fluent-bit-sidecar
   
   # 檢查端口是否開放
   curl http://localhost:8888
   ```

3. **配置文件路徑錯誤**：
   - 確保從 `tests/` 目錄運行測試
   - 或調整配置文件路徑
