#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# test_common_filters.rb - 通用 Filter 邏輯測試
# 測試所有微服務共用的 Filter 邏輯（record_transformer, grep 等）

require_relative '../../test_helper'
require 'fluent/plugin/filter_grep'

class CommonFiltersTest < Test::Unit::TestCase
  
  # ============================================================
  # Test 1: Record Transformer - 基礎字段添加
  # ============================================================
  def test_record_transformer_adds_basic_fields
    # 在測試中，使用固定值而不是 Socket.gethostname（因為在配置字符串中插值會有問題）
    conf = <<~'CONF'
      <record>
        hostname "test-host"
        service_name "test-service"
        environment "test"
      </record>
    CONF
    
    d = create_filter_driver(Fluent::Plugin::RecordTransformerFilter, conf)
    time = event_time("2026-01-07 10:00:00 UTC")
    
    d.run(default_tag: 'test.service') do
      d.feed(time, {"log" => "test message"})
    end
    
    filtered = d.filtered_records
    assert_equal 1, filtered.length
    assert_equal "test-service", filtered[0]["service_name"]
    assert_equal "test", filtered[0]["environment"]
    assert_not_nil filtered[0]["hostname"]
  end

  # ============================================================
  # Test 2: Record Transformer - 錯誤檢測邏輯
  # ============================================================
  def test_record_transformer_error_detection
    conf = <<~'CONF'
      enable_ruby true
      <record>
        is_error ${ (record["log"].to_s =~ /ERROR/ || record["message"].to_s =~ /ERROR/) ? "true" : "false" }
      </record>
    CONF
    
    d = create_filter_driver(Fluent::Plugin::RecordTransformerFilter, conf)
    time = event_time("2026-01-07 10:00:00 UTC")
    
    # 測試錯誤日誌
    d.run(default_tag: 'test.service') do
      d.feed(time, {"log" => "ERROR - Something went wrong"})
    end
    
    filtered = d.filtered_records
    assert_equal "true", filtered[0]["is_error"]
    
    # 測試正常日誌
    d2 = create_filter_driver(Fluent::Plugin::RecordTransformerFilter, conf)
    d2.run(default_tag: 'test.service') do
      d2.feed(time, {"log" => "INFO - Request processed"})
    end
    
    filtered2 = d2.filtered_records
    assert_equal "false", filtered2[0]["is_error"]
  end

  # ============================================================
  # Test 3: Grep Filter - 過濾錯誤日誌
  # ============================================================
  def test_grep_filter_error_logs
    conf = <<~'CONF'
      <exclude>
        key is_error
        pattern /^false$/
      </exclude>
    CONF
    
    d = create_filter_driver(Fluent::Plugin::GrepFilter, conf)
    time = event_time("2026-01-07 10:00:00 UTC")
    
    # 混合輸入：正常日誌和錯誤日誌
    d.run(default_tag: 'app.error') do
      d.feed(time, {"is_error" => "false", "message" => "Normal log"})
      d.feed(time, {"is_error" => "true", "message" => "Error log"})
    end
    
    filtered = d.filtered_records
    
    # 應該只保留錯誤日誌
    assert_equal 1, filtered.length, "應該只保留錯誤日誌"
    assert_equal "true", filtered[0]["is_error"]
  end
end

