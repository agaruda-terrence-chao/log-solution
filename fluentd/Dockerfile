# # 舊方案
# FROM fluent/fluentd:v1.16-debian-1

# USER root

# # 安装 OpenSearch 输出插件
# RUN gem install fluent-plugin-opensearch

# # 安装 rewrite-tag-filter 和 grep 插件（用于路由和过滤）
# RUN gem install fluent-plugin-rewrite-tag-filter fluent-plugin-grep

# # 安装 netcat 用于健康检查
# RUN apt-get update && apt-get install -y netcat-openbsd && rm -rf /var/lib/apt/lists/*

# USER fluent


# 新方案: fluent-package
FROM fluent/fluentd:v1.17-debian-1

USER root

# fluent-package 也預裝常用插件，通常只需安裝 OpenSearch 插件
RUN fluent-gem install fluent-plugin-opensearch || \
    gem install fluent-plugin-opensearch

# 安裝 rewrite-tag-filter 和 grep 插件（用於路由和過濾）
# 注意: relabel 功能可以使用 @label 指令（Fluentd 1.14+ 内置支持）
RUN fluent-gem install fluent-plugin-rewrite-tag-filter fluent-plugin-grep || \
    gem install fluent-plugin-rewrite-tag-filter fluent-plugin-grep

# 安裝 netcat 用於健康檢查
RUN apt-get update && apt-get install -y netcat-openbsd && rm -rf /var/lib/apt/lists/*

# 創建 buffer 目錄（file buffer 需要）
RUN mkdir -p /fluentd/buffers && chown -R fluent:fluent /fluentd/buffers

USER fluent

# fluent-package 使用 fluentd 命令（與當前相同）
CMD ["fluentd"]
