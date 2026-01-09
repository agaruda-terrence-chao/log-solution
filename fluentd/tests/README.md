# Fluentd ETL Tests

这个目录包含 Fluentd 配置文件的测试，专注于验证 ETL 处理逻辑的正确性。

## 测试内容

### 1. ETL 逻辑单元测试 (`test_etl_logic.rb`)

测试 `conf2/fluent.conf` 中的 ETL 处理逻辑：

- ✅ **基础字段添加** - 验证 @APP 标签是否正确添加 service_name、etl_node 等字段
- ✅ **错误检测逻辑** - 验证是否能正确识别 ERROR 日志并设置 log_level、is_error、error_category
- ✅ **错误分类** - 验证是否能区分 validation_error 和 general_error
- ✅ **系统指标处理** - 验证 @SYSTEM 标签是否正确处理系统指标数据
- ✅ **错误告警字段** - 验证 @APP_ERRORS 标签是否正确添加告警字段
- ✅ **完整处理链** - 验证从输入到输出的完整 ETL 流程

### 2. 配置语法验证 (`test_config_syntax.rb`)

验证配置文件的语法和结构：

- ✅ 配置文件是否存在
- ✅ 必需的 sections 和 labels 是否存在
- ✅ 必需的插件是否正确配置
- ✅ Label 路由是否完整
- ✅ XML 结构是否正确

## 快速开始

### 方法 1: 使用测试脚本（推荐，适合 CI/CD）

```bash
cd playground/log-solution/fluentd/tests
chmod +x test.sh
./test.sh
```

### 方法 2: 使用 Makefile

```bash
cd playground/log-solution/fluentd/tests
make test          # 运行所有测试
make test-etl      # 只运行 ETL 逻辑测试
make test-syntax   # 只运行语法验证
```

### 方法 3: 直接运行 Ruby 测试（需要本地环境）

```bash
cd playground/log-solution/fluentd/tests
bundle install
ruby test_etl_logic.rb      # ETL 逻辑测试
ruby test_config_syntax.rb  # 语法验证
```

## CI/CD 集成

### GitHub Actions

GitHub Actions 工作流已配置在 `playground/log-solution/fluentd/.github/workflows/test.yml`，会自动运行测试。

### GitLab CI

在 `.gitlab-ci.yml` 中添加:

```yaml
fluentd_test:
  image: docker:latest
  services:
    - docker:dind
  script:
    - cd playground/log-solution/fluentd/tests
    - chmod +x test.sh
    - ./test.sh
  only:
    changes:
      - playground/log-solution/fluentd/**/*
```

## 测试输出示例

```
======================================
Fluentd ETL Logic Tests
======================================

测试目录: /path/to/tests
配置文件: /path/to/conf2/fluent.conf

--------------------------------------
测试: 配置语法验证
文件: test_config_syntax.rb
--------------------------------------
Loaded suite test_config_syntax
Started
...
Finished in 0.123456 seconds.

4 tests, 4 assertions, 0 failures, 0 errors
✅ 配置语法验证 通过

--------------------------------------
测试: ETL 逻辑单元测试
文件: test_etl_logic.rb
--------------------------------------
Loaded suite test_etl_logic
Started
...
Finished in 0.234567 seconds.

8 tests, 24 assertions, 0 failures, 0 errors
✅ ETL 逻辑单元测试 通过

======================================
✅ 所有测试通过！
配置文件已验证，ETL 逻辑正确
```

## 文件说明

- `test_etl_logic.rb` - **主要测试文件**，测试 ETL 处理逻辑
- `test_config_syntax.rb` - 配置语法验证测试
- `test.sh` - 统一的测试运行脚本（适合 CI/CD）
- `Makefile` - 便捷的测试命令
- `Gemfile` - Ruby 测试依赖

## 部署到 ArgoCD

### CI/CD 流程

1. **提交代码**：修改 `conf2/fluent.conf` 后提交到 Git
2. **自动测试**：GitHub Actions 自动运行测试（`.github/workflows/test.yml`）
3. **测试通过**：如果所有测试通过，代码可以合并到主分支
4. **ArgoCD 同步**：ArgoCD 会自动检测到 Helm Chart 的变化并同步到 Kubernetes

### 手动部署流程

如果测试通过，可以手动部署：

```bash
# 1. 运行测试确保配置正确
cd playground/log-solution/fluentd/tests
make test

# 2. 构建 Docker 镜像（如果需要）
cd ../..
docker build -t registry.internal.agaruda.io/agaruda/fluentd-aggregator:latest \
  -f fluentd/Dockerfile fluentd/

# 3. 推送镜像到 Harbor
docker push registry.internal.agaruda.io/agaruda/fluentd-aggregator:latest

# 4. 使用 Helm 部署到 K8S
cd charts/fluentd-aggregator
make install
```

### ArgoCD Application 配置

如果需要通过 ArgoCD 自动部署，创建 Application 配置：

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: fluentd-aggregator
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/Agaruda/devops-app-helm.git
    targetRevision: main
    path: charts/fluentd-aggregator
    helm:
      releaseName: fluentd-aggregator
  destination:
    server: https://kubernetes.default.svc
    namespace: log-solution
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**注意**：部署前确保：
- ✅ 所有测试通过：`make test`
- ✅ 配置文件语法正确：`make test-syntax`
- ✅ ETL 逻辑测试通过：`make test-etl`

## 故障排查

### 测试失败

1. **依赖问题**: 运行 `bundle install` 安装依赖
2. **Docker 问题**: 确保 Docker 可用，或使用本地 Ruby 环境
3. **配置文件路径**: 确保 `conf2/fluent.conf` 存在

### 常见问题

- **插件缺失**: 确保 Dockerfile 中安装了所有必需的插件
- **语法错误**: 检查配置文件中的 XML 标签是否正确关闭
- **标签路由错误**: 确认所有 `@label` 指令指向存在的 label
