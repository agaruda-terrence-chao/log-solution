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
    assert_match(/<label @APP>/, content, "应该有 @APP label")
    assert_match(/<label @SYSTEM>/, content, "应该有 @SYSTEM label")
    assert_match(/<label @APP_ERRORS>/, content, "应该有 @APP_ERRORS label")
    
    # 检查必需的插件
    assert_match(/@type forward/, content, "应该使用 forward input")
    assert_match(/@type http/, content, "应该使用 http input")
    assert_match(/@type opensearch/, content, "应该使用 opensearch output")
    assert_match(/@type record_transformer/, content, "应该使用 record_transformer filter")
    assert_match(/@type rewrite_tag_filter/, content, "应该使用 rewrite_tag_filter")
  end

  # ============================================================
  # Test 3: Label 路由完整性
  # ============================================================
  def test_label_routing_completeness
    skip "配置文件不存在: #{@config_file}" unless File.exist?(@config_file)
    
    content = File.read(@config_file)
    
    # 验证所有 labels 都正确关闭
    labels = content.scan(/<label @(\w+)>/).flatten
    label_ends = content.scan(/<\/label>/).length
    
    assert_equal labels.length, label_ends, "所有 labels 应该正确关闭 (找到 #{labels.length} 个 label, #{label_ends} 个关闭标签)"
    
    # 验证 label 路由
    assert_match(/@label @APP/, content, "Source 应该路由到 @APP label")
    assert_match(/@label @SYSTEM/, content, "Source 应该路由到 @SYSTEM label")
    assert_match(/@label @APP_ERRORS/, content, "应该路由到 @APP_ERRORS label")
  end

  # ============================================================
  # Test 4: 基本语法检查（XML 结构）
  # ============================================================
  def test_basic_syntax_structure
    skip "配置文件不存在: #{@config_file}" unless File.exist?(@config_file)
    
    content = File.read(@config_file)
    
    # 检查 record sections 中的引号是否平衡
    record_sections = content.scan(/<record>(.*?)<\/record>/m)
    record_sections.each do |section|
      quote_count = section[0].scan(/"/).length
      assert_equal 0, quote_count % 2, "record section 中的引号应该平衡"
    end
  end
end
