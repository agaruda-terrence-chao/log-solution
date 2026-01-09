# Fluentd ETL Tests

這個目錄包含 Fluentd 配置文件的測試，專注於驗證 `conf.d/` 中各微服務的 ETL 處理邏輯。

## 測試結構

```
tests/
├── test_config_syntax.rb              # 配置語法驗證
├── test_helper.rb                      # 測試輔助函數
├── unit/                               # 單元測試（通用邏輯）
│   └── filters/
│       └── test_common_filters.rb     # 通用 Filter 邏輯測試
├── integration/                        # 整合測試（按微服務）
│   └── services/
│       └── fastapi_app/
│           ├── test_fastapi_app_etl.rb
│           └── fixtures/
│               ├── api_success_logs.json
│               └── api_error_logs.json
├── Makefile
├── test.sh
└── Gemfile
```

## 設計理念

### 分層結構
- **單元測試（unit/）**：測試所有微服務共用的通用 Filter 邏輯（如 record_transformer、grep），可復用
- **整合測試（integration/services/）**：按微服務組織，測試每個微服務的完整 ETL 流程

### 可擴展性
- 新增微服務時，只需在 `integration/services/` 下創建對應目錄和測試文件
- 通用邏輯的測試在 `unit/` 中，無需重複編寫

## 測試內容

### 1. 配置語法驗證 (`test_config_syntax.rb`)

驗證配置文件的語法和結構：
- ✅ 配置文件是否存在
- ✅ 必需的 sections 和 labels 是否存在
- ✅ conf.d/ 目錄結構
- ✅ Label 路由是否完整

### 2. 單元測試 (`unit/filters/test_common_filters.rb`)

測試所有微服務共用的 Filter 邏輯：
- ✅ Record Transformer - 基礎字段添加
- ✅ Record Transformer - 錯誤檢測邏輯
- ✅ Grep Filter - 過濾錯誤日誌

### 3. 整合測試 (`integration/services/`)

按微服務測試完整的 ETL 流程：

#### FastAPI App (`fastapi_app/test_fastapi_app_etl.rb`)
- ✅ 成功日誌處理（`/test` API）
- ✅ 錯誤日誌處理（`/test` API）
- ✅ 完整 Pipeline（@APP → @APP_ERRORS）

## 快速開始

### ⚡ 性能優化（重要）

測試已優化為使用預構建的 Docker 鏡像，**執行速度提升 100-200 倍**！

- **首次運行**：會自動構建 Docker 鏡像（約 2-3 分鐘，只需一次）
- **後續運行**：直接使用預構建鏡像，測試執行僅需 **1-2 秒**
- **優化前**：每次運行都需要安裝依賴，耗時 60-135 秒

詳細說明請參閱 [OPTIMIZATION.md](./OPTIMIZATION.md)

### 方法 1: 使用 Makefile（推薦）

```bash
cd playground/log-solution/fluentd/tests

# 首次運行（會自動構建 Docker 鏡像）
make test              # 運行所有測試（約 2 秒，首次需構建鏡像）

# 或者手動構建鏡像
make build-image       # 構建測試環境 Docker 鏡像
make test              # 運行所有測試

# 運行特定測試
make test-syntax       # 只運行配置語法驗證（約 0.3 秒）
make test-unit         # 只運行單元測試（約 0.5 秒）
make test-integration  # 只運行整合測試（約 0.5 秒）
make test-fastapi      # 只運行 FastAPI 測試（約 0.3 秒）

# 使用本地 Ruby 環境（最快，需要安裝 Ruby 3.2+）
USE_LOCAL=true make test
```

### 方法 2: 使用測試腳本

```bash
cd playground/log-solution/fluentd/tests
chmod +x test.sh
./test.sh
```

### 方法 3: 直接運行 Ruby 測試

```bash
cd playground/log-solution/fluentd/tests
bundle install
bundle exec ruby test_config_syntax.rb
bundle exec ruby unit/filters/test_common_filters.rb
bundle exec ruby integration/services/fastapi_app/test_fastapi_app_etl.rb
```

## 添加新微服務測試

當在 `conf.d/` 中添加新的微服務配置時（如 `service-user-service.conf`），按以下步驟添加測試：

1. **創建測試目錄和文件**：
```bash
mkdir -p integration/services/user_service/fixtures
touch integration/services/user_service/test_user_service_etl.rb
```

2. **編寫測試文件**（參考 `fastapi_app/test_fastapi_app_etl.rb`）：
```ruby
require_relative '../../../test_helper'

class UserServiceETLTest < Test::Unit::TestCase
  def test_user_service_etl
    # 測試邏輯
  end
end
```

3. **運行測試**：
```bash
make test-integration
# 或
ruby integration/services/user_service/test_user_service_etl.rb
```

## CI/CD 集成

GitHub Actions 工作流已配置在 `.github/workflows/fluentd-test.yml`，會自動運行測試。

## 文件說明

- `test_config_syntax.rb` - 配置語法驗證測試
- `test_helper.rb` - 測試輔助函數（創建驅動器、載入 fixtures 等）
- `unit/filters/test_common_filters.rb` - 通用 Filter 邏輯測試（可復用）
- `integration/services/*/test_*_etl.rb` - 各微服務的 ETL 整合測試
- `test.sh` - 統一的測試運行腳本（適合 CI/CD）
- `Makefile` - 便捷的測試命令
- `Gemfile` - Ruby 測試依賴

## 故障排查

### 測試失敗

1. **依賴問題**: 運行 `bundle install` 安裝依賴
2. **Docker 問題**: 確保 Docker 可用，或使用本地 Ruby 環境
3. **配置文件路徑**: 確保 `conf/fluent2.conf` 和 `conf.d/*-2.conf` 存在

### 常見問題

- **插件缺失**: 確保 Dockerfile 中安裝了所有必需的插件
- **語法錯誤**: 檢查配置文件中的 XML 標籤是否正確關閉
- **標籤路由錯誤**: 確認所有 `@label` 指令指向存在的 label
