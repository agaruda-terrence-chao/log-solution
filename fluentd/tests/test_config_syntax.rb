#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
#
# Configuration Syntax Validation Test
# 验证 fluentd/conf/fluent2.conf 的语法是否正确
#

require 'test/unit'

class FluentdConfigSyntaxTest < Test::Unit::TestCase
  
  def setup
    # 優先檢查 fluent3.conf，如果不存在則使用 fluent2.conf
    fluent3_config = File.expand_path(File.join(__dir__, '..', 'conf', 'fluent3.conf'))
    fluent2_config = File.expand_path(File.join(__dir__, '..', 'conf', 'fluent2.conf'))
    
    if File.exist?(fluent3_config)
      @config_file = fluent3_config
      @config_version = '3'
    elsif File.exist?(fluent2_config)
      @config_file = fluent2_config
      @config_version = '2'
    else
      raise "配置文件不存在: #{fluent3_config} 或 #{fluent2_config}"
    end
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
    
    content = File.read(@config_file, encoding: 'UTF-8')
    
    # 检查必需的 sections
    assert_match(/<system>/, content, "应该有 <system> 部分")
    assert_match(/<source>/, content, "应该有 <source> 部分")
    
    # 检查 @include 指令（新的配置结构）
    assert_match(/@include/, content, "应该使用 @include 引用 conf.d/")
    
    # 检查必需的插件
    assert_match(/@type forward/, content, "应该使用 forward input")
    
    # opensearch output 在 conf.d/ 的服务配置文件中，不在主配置文件
    # 检查 conf.d/ 中是否有 opensearch output
    conf_d_dir = File.join(File.dirname(@config_file), '..', 'conf.d')
    if File.directory?(conf_d_dir)
      service_configs = Dir.glob(File.join(conf_d_dir, 'service-*.conf'))
      has_opensearch = service_configs.any? do |config_file|
        File.read(config_file, encoding: 'UTF-8').include?('@type opensearch')
      end
      assert has_opensearch, "conf.d/ 中的服务配置文件应该包含 opensearch output"
    end
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
    
    # 根据配置版本检查不同的配置文件
    if @config_version == '3'
      # 检查 order-app 配置
      order_config = File.join(conf_d_dir, 'service-order-app-3.conf')
      if File.exist?(order_config)
        content = File.read(order_config, encoding: 'UTF-8')
        assert_match(/<label @ORDER_APP>/, content, "service-order-app-3.conf 应该包含 @ORDER_APP label")
        assert_match(/<label @ORDER_APP_NORMAL>/, content, "service-order-app-3.conf 应该包含 @ORDER_APP_NORMAL label")
        assert_match(/<label @ORDER_APP_ERRORS>/, content, "service-order-app-3.conf 应该包含 @ORDER_APP_ERRORS label")
      end
      
      # 检查 user-app 配置
      user_config = File.join(conf_d_dir, 'service-user-app-3.conf')
      if File.exist?(user_config)
        content = File.read(user_config, encoding: 'UTF-8')
        assert_match(/<label @USER_APP>/, content, "service-user-app-3.conf 应该包含 @USER_APP label")
        assert_match(/<label @USER_APP_NORMAL>/, content, "service-user-app-3.conf 应该包含 @USER_APP_NORMAL label")
        assert_match(/<label @USER_APP_ERRORS>/, content, "service-user-app-3.conf 应该包含 @USER_APP_ERRORS label")
      end
    else
      # 检查 fastapi-app 配置（v2）
      fastapi_config = File.join(conf_d_dir, 'service-fastapi-app-2.conf')
      if File.exist?(fastapi_config)
        content = File.read(fastapi_config, encoding: 'UTF-8')
        assert_match(/<label @APP>/, content, "service-fastapi-app-2.conf 应该包含 @APP label")
        assert_match(/<label @APP_ERRORS>/, content, "service-fastapi-app-2.conf 应该包含 @APP_ERRORS label")
      end
    end
  end

  # ============================================================
  # Test 3: Label 路由完整性
  # ============================================================
  def test_label_routing_completeness
    skip "配置文件不存在: #{@config_file}" unless File.exist?(@config_file)
    
    content = File.read(@config_file, encoding: 'UTF-8')
    
    # 验证所有 labels 都正确关闭（主配置文件）
    labels = content.scan(/<label @(\w+)>/).flatten
    label_ends = content.scan(/<\/label>/).length
    
    assert_equal labels.length, label_ends, "所有 labels 应该正确关闭 (找到 #{labels.length} 个 label, #{label_ends} 个关闭标签)"
    
    # 验证 conf.d/ 中的 label 路由
    conf_d_dir = File.join(File.dirname(@config_file), '..', 'conf.d')
    if File.directory?(conf_d_dir)
      if @config_version == '3'
        # v3 配置：检查 order-app 和 user-app
        order_config = File.join(conf_d_dir, 'service-order-app-3.conf')
        if File.exist?(order_config)
          config_content = File.read(order_config, encoding: 'UTF-8')
          assert_match(/<label @ORDER_APP>/, config_content, "service-order-app-3.conf 应该包含 @ORDER_APP label")
          assert_match(/<label @ORDER_APP_NORMAL>/, config_content, "service-order-app-3.conf 应该包含 @ORDER_APP_NORMAL label")
          assert_match(/<label @ORDER_APP_ERRORS>/, config_content, "service-order-app-3.conf 应该包含 @ORDER_APP_ERRORS label")
        end
        
        user_config = File.join(conf_d_dir, 'service-user-app-3.conf')
        if File.exist?(user_config)
          config_content = File.read(user_config, encoding: 'UTF-8')
          assert_match(/<label @USER_APP>/, config_content, "service-user-app-3.conf 应该包含 @USER_APP label")
          assert_match(/<label @USER_APP_NORMAL>/, config_content, "service-user-app-3.conf 应该包含 @USER_APP_NORMAL label")
          assert_match(/<label @USER_APP_ERRORS>/, config_content, "service-user-app-3.conf 应该包含 @USER_APP_ERRORS label")
        end
      else
        # v2 配置：检查 fastapi-app
        service_configs = Dir.glob(File.join(conf_d_dir, 'service-*-2.conf'))
        service_configs.each do |config_file|
          config_content = File.read(config_file, encoding: 'UTF-8')
          assert_match(/<label @APP>/, config_content, "#{File.basename(config_file)} 应该包含 @APP label")
          assert_match(/<label @APP_ERRORS>/, config_content, "#{File.basename(config_file)} 应该包含 @APP_ERRORS label")
        end
      end
    end
  end

  # ============================================================
  # Test 4: 基本语法检查（XML 结构）
  # ============================================================
  def test_basic_syntax_structure
    skip "配置文件不存在: #{@config_file}" unless File.exist?(@config_file)
    
    content = File.read(@config_file, encoding: 'UTF-8')
    
    # 检查 record sections 中的引号是否平衡（跳过注释中的引号）
    record_sections = content.scan(/<record>(.*?)<\/record>/m)
    record_sections.each do |section|
      # 移除注释行
      section_content = section[0].gsub(/^\s*#.*$/, '')
      quote_count = section_content.scan(/"/).length
      # 允许引号数量为偶数（成对）或 0
      assert quote_count % 2 == 0, "record section 中的引号应该平衡 (找到 #{quote_count} 个引号)"
    end
    
    # 检查 conf.d/ 中的配置文件
    conf_d_dir = File.join(File.dirname(@config_file), '..', 'conf.d')
    if File.directory?(conf_d_dir)
      service_configs = Dir.glob(File.join(conf_d_dir, 'service-*.conf'))
      service_configs.each do |config_file|
        config_content = File.read(config_file, encoding: 'UTF-8')
        config_record_sections = config_content.scan(/<record>(.*?)<\/record>/m)
        config_record_sections.each do |section|
          section_content = section[0].gsub(/^\s*#.*$/, '')
          quote_count = section_content.scan(/"/).length
          assert quote_count % 2 == 0, "#{File.basename(config_file)} record section 中的引号应该平衡 (找到 #{quote_count} 个引号)"
        end
      end
    end
  end
end
