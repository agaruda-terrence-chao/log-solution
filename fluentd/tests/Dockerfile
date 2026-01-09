# Fluentd Test Environment Dockerfile
# 预构建包含所有依赖的测试镜像，避免每次运行都安装依赖

FROM ruby:3.2-slim

# 安装系统依赖（build-essential 用于编译 native gems）
RUN apt-get update -qq > /dev/null 2>&1 && \
    apt-get install -y -qq build-essential > /dev/null 2>&1 && \
    rm -rf /var/lib/apt/lists/*

# 安装 bundler
RUN gem install bundler -v "~> 2.4" --quiet --no-document

# 设置工作目录
WORKDIR /workspace/fluentd/tests

# 先复制 Gemfile 和 Gemfile.lock（如果存在）以利用 Docker 缓存
# 注意：构建上下文应该在 tests 目录，所以直接复制当前目录的文件
COPY Gemfile* ./

# 安装 gem 依赖（使用 --quiet 和 --no-document 加快速度）
RUN bundle config set --local deployment 'false' && \
    bundle config set --local without '' && \
    bundle install --quiet --jobs 4 --retry 3

# 默认命令
CMD ["bash"]

