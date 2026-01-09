#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
#
# Configuration Syntax Validation Test
# 验证 fluentd/conf2/fluent.conf 的语法是否正确
#

require 'test/unit'

class FluentdConfigSyntaxTest < Test::Unit::TestCase
  
  def setup
    @config_file = File.expand_path(File.join(__dir__, '..', 'conf2', 'fluent.conf'))
  end

  # ============================================================
  # Test 1: 配置文件是否存在
  # ============================================================
  def test_config_file_exists
    assert File.exist?(@config_file), "配置文件应该存在: #{@config_file}"
  end

  # ============================================================
  # Test 2: 配置文件结构完整性
  # ============================================================
  def test_config_file_structure
    skip "配置文件不存在: #{@config_file}" unless File.exist?(@config_file)
    
    content = File.read(@config_file)
    
    # 检查必需的 sections
    assert_match(/<system>/, content, "应该有 <system> 部分")
    assert_match(/<source>/, content, "应该有 <source> 部分")
    assert_match(/<label @SYSTEM>/, content, "应该有 @SYSTEM label")
    
    # 检查 @include 指令（新的配置结构）
    assert_match(/@include/, content, "应该使用 @include 引用 conf.d/")
    
    # 检查必需的插件
    assert_match(/@type forward/, content, "应该使用 forward input")
    assert_match(/@type http/, content, "应该使用 http input")
    assert_match(/@type opensearch/, content, "应该使用 opensearch output")
  end

  # ============================================================
  # Test 2.1: conf.d/ 目录结构
  # ============================================================
  def test_conf_d_directory_structure
    conf_d_dir = File.join(File.dirname(@config_file), '..', 'conf.d')
    skip "conf.d 目录不存在: #{conf_d_dir}" unless File.directory?(conf_d_dir)
    
    # 检查是否有微服务配置文件
    service_configs = Dir.glob(File.join(conf_d_dir, 'service-*.conf'))
    assert service_configs.length > 0, "conf.d/ 目录应该包含至少一个微服务配置文件"
    
    # 检查 fastapi-app 配置
    fastapi_config = File.join(conf_d_dir, 'service-fastapi-app.conf')
    assert File.exist?(fastapi_config), "应该有 service-fastapi-app.conf 配置文件"
    
    # 检查配置文件内容
    if File.exist?(fastapi_config)
      content = File.read(fastapi_config)
      assert_match(/<label @APP>/, content, "service-fastapi-app.conf 应该包含 @APP label")
      assert_match(/<label @APP_ERRORS>/, content, "service-fastapi-app.conf 应该包含 @APP_ERRORS label")
    end
  end

  # ============================================================
  # Test 3: Label 路由完整性
  # ============================================================
  def test_label_routing_completeness
    skip "配置文件不存在: #{@config_file}" unless File.exist?(@config_file)
    
    content = File.read(@config_file)
    
    # 验证所有 labels 都正确关闭（主配置文件）
    labels = content.scan(/<label @(\w+)>/).flatten
    label_ends = content.scan(/<\/label>/).length
    
    assert_equal labels.length, label_ends, "所有 labels 应该正确关闭 (找到 #{labels.length} 个 label, #{label_ends} 个关闭标签)"
    
    # 验证 label 路由（主配置文件）
    assert_match(/@label @SYSTEM/, content, "Source 应该路由到 @SYSTEM label")
    
    # 验证 conf.d/ 中的 label 路由
    conf_d_dir = File.join(File.dirname(@config_file), '..', 'conf.d')
    if File.directory?(conf_d_dir)
      service_configs = Dir.glob(File.join(conf_d_dir, 'service-*.conf'))
      service_configs.each do |config_file|
        config_content = File.read(config_file)
        assert_match(/<label @APP>/, config_content, "#{File.basename(config_file)} 应该包含 @APP label")
        assert_match(/<label @APP_ERRORS>/, config_content, "#{File.basename(config_file)} 应该包含 @APP_ERRORS label")
      end
    end
  end

  # ============================================================
  # Test 4: 基本语法检查（XML 结构）
  # ============================================================
  def test_basic_syntax_structure
    skip "配置文件不存在: #{@config_file}" unless File.exist?(@config_file)
    
    content = File.read(@config_file)
    
    # 检查 record sections 中的引号是否平衡（跳过注释中的引号）
    record_sections = content.scan(/<record>(.*?)<\/record>/m)
    record_sections.each do |section|
      # 移除注释行
      section_content = section[0].gsub(/^\s*#.*$/, '')
      quote_count = section_content.scan(/"/).length
      # 允许引号数量为偶数（成对）或 0
      assert quote_count % 2 == 0, "record section 中的引号应该平衡 (找到 #{quote_count} 个引号)"
    end
  end
end
