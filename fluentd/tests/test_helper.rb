#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# test_helper.rb - 測試輔助函數，提供共用功能

require 'test/unit'
require 'fluent/test'
require 'fluent/test/driver/filter'
require 'fluent/test/driver/output'
require 'fluent/plugin/filter_record_transformer'
require 'fluent/plugin/filter_grep'
require 'json'
require 'time'

module FluentdTestHelper
  # 創建 Filter 驅動器
  def create_filter_driver(plugin_class, conf)
    Fluent::Test.setup
    Fluent::Test::Driver::Filter.new(plugin_class).configure(conf)
  end

  # 創建 Output 驅動器
  def create_output_driver(plugin_class, conf)
    Fluent::Test.setup
    Fluent::Test::Driver::Output.new(plugin_class).configure(conf)
  end

  # 創建事件時間
  def event_time(str)
    Fluent::EventTime.from_time(Time.parse(str))
  end

  # 載入測試數據夾具（fixture）
  def load_fixture(service_name, fixture_name)
    fixture_path = File.join(__dir__, 'integration', 'services', service_name, 'fixtures', fixture_name)
    if File.exist?(fixture_path)
      JSON.parse(File.read(fixture_path))
    else
      raise "Fixture not found: #{fixture_path}"
    end
  end

  # 模擬微服務 API 日誌格式
  # 根據 fastapi-app/main.py 的實際日誌格式：[FASTAPI-APP] %(asctime)s - %(name)s - %(levelname)s - %(message)s
  # 實際輸出：[FASTAPI-APP] 2026-01-07 10:00:00,123 - root - INFO - SUCCESS - Query parameter is 'yolo' | timestamp=... | status=200
  def create_api_log(service_name, api_path, level, message, **extra_fields)
    timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
    # 注意：實際日誌中，api_path 和 message 都在 message 部分，格式為：/path - message
    # 但為了測試方便，我們直接構造完整的日誌字符串
    log_message = "[#{service_name.upcase}] #{timestamp} - root - #{level} - #{message}"
    
    {
      "log" => log_message,
      "message" => message,
      "service" => service_name,
      "api_path" => api_path,
      "level" => level,
      "timestamp" => timestamp,
      **extra_fields
    }
  end

  # 驗證 ETL 輸出結構
  def assert_etl_output_structure(record, expected_service, expected_fields = {})
    assert_not_nil record, "記錄不應該為空"
    assert_equal expected_service, record["service_name"], "service_name 應該匹配"
    
    expected_fields.each do |key, value|
      assert_equal value, record[key.to_s], "#{key} 應該匹配預期值"
    end
  end

  # 驗證錯誤日誌結構
  def assert_error_log_structure(record, expected_service)
    assert_not_nil record, "錯誤記錄不應該為空"
    assert_equal expected_service, record["service_name"]
    assert_equal "true", record["is_error"], "is_error 應該是 true"
    assert_not_nil record["alert_priority"], "應該有 alert_priority 字段"
    assert_not_nil record["troubleshoot_hint"], "應該有 troubleshoot_hint 字段"
  end

  # 驗證成功日誌結構
  def assert_success_log_structure(record, expected_service)
    assert_not_nil record, "成功記錄不應該為空"
    assert_equal expected_service, record["service_name"]
    assert_equal "false", record["is_error"], "is_error 應該是 false"
  end
end

# 包含到所有測試類
Test::Unit::TestCase.include(FluentdTestHelper)

