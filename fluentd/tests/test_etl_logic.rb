#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
#
# ETL Logic Unit Tests for fluentd/conf2/fluent.conf
# 测试 ETL 处理逻辑是否正确
# 适合 CI/CD 流程
#

require 'test/unit'
require 'fluent/test'
require 'fluent/test/driver/filter'
require 'fluent/plugin/filter_record_transformer'

class FluentdETLLogicTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  # ============================================================
  # Test 1: 基础字段添加（@APP 标签处理）
  # ============================================================
  def test_app_label_adds_basic_fields
    conf = %[
      <record>
        hostname "#{Socket.gethostname}"
        service_name "fastapi-app"
        etl_node "app-processor"
      </record>
    ]
    
    d = create_filter(conf)
    time = event_time("2026-01-07 10:00:00 UTC")
    
    d.run(default_tag: 'fastapi.app') do
      d.feed(time, {"log" => "test message"})
    end
    
    filtered = d.filtered_records
    assert_equal 1, filtered.length, "应该有 1 条记录"
    assert_equal "fastapi-app", filtered[0]["service_name"], "service_name 应该为 fastapi-app"
    assert_equal "app-processor", filtered[0]["etl_node"], "etl_node 应该为 app-processor"
    assert_not_nil filtered[0]["hostname"], "hostname 不应该为空"
  end

  # ============================================================
  # Test 2: 错误检测逻辑 - ERROR 日志
  # ============================================================
  def test_error_detection_for_error_logs
    conf = %[
      enable_ruby true
      <record>
        log_level ${record["log"] && record["log"].include?("ERROR") ? "ERROR" : "INFO"}
        is_error ${record["log"] && record["log"].include?("ERROR") ? "true" : "false"}
        error_category ${if record["log"] && record["log"].include?("ERROR"); record["log"].include?("validation") ? "validation_error" : "general_error"; else; ""; end}
      </record>
    ]
    
    d = create_filter(conf)
    time = event_time("2026-01-07 10:00:00 UTC")
    
    d.run(default_tag: 'fastapi.app') do
      d.feed(time, {"log" => "ERROR - Invalid request parameter"})
    end
    
    filtered = d.filtered_records
    assert_equal 1, filtered.length
    assert_equal "ERROR", filtered[0]["log_level"], "ERROR 日志的 log_level 应该是 ERROR"
    assert_equal "true", filtered[0]["is_error"], "ERROR 日志的 is_error 应该是 true"
    assert_equal "general_error", filtered[0]["error_category"], "应该识别为 general_error"
  end

  # ============================================================
  # Test 3: 错误检测逻辑 - 验证错误（validation error）
  # ============================================================
  def test_error_detection_for_validation_errors
    conf = %[
      enable_ruby true
      <record>
        log_level ${record["log"] && record["log"].include?("ERROR") ? "ERROR" : "INFO"}
        is_error ${record["log"] && record["log"].include?("ERROR") ? "true" : "false"}
        error_category ${if record["log"] && record["log"].include?("ERROR"); record["log"].include?("validation") ? "validation_error" : "general_error"; else; ""; end}
      </record>
    ]
    
    d = create_filter(conf)
    time = event_time("2026-01-07 10:00:00 UTC")
    
    d.run(default_tag: 'fastapi.app') do
      d.feed(time, {"log" => "ERROR - validation failed: required field missing"})
    end
    
    filtered = d.filtered_records
    assert_equal 1, filtered.length
    assert_equal "ERROR", filtered[0]["log_level"]
    assert_equal "true", filtered[0]["is_error"]
    assert_equal "validation_error", filtered[0]["error_category"], "包含 validation 的 ERROR 应该识别为 validation_error"
  end

  # ============================================================
  # Test 4: 错误检测逻辑 - INFO 日志（非错误）
  # ============================================================
  def test_error_detection_for_info_logs
    conf = %[
      enable_ruby true
      <record>
        log_level ${record["log"] && record["log"].include?("ERROR") ? "ERROR" : "INFO"}
        is_error ${record["log"] && record["log"].include?("ERROR") ? "true" : "false"}
        error_category ${if record["log"] && record["log"].include?("ERROR"); record["log"].include?("validation") ? "validation_error" : "general_error"; else; ""; end}
      </record>
    ]
    
    d = create_filter(conf)
    time = event_time("2026-01-07 10:00:00 UTC")
    
    d.run(default_tag: 'fastapi.app') do
      d.feed(time, {"log" => "INFO - Request processed successfully"})
    end
    
    filtered = d.filtered_records
    assert_equal 1, filtered.length
    assert_equal "INFO", filtered[0]["log_level"], "INFO 日志的 log_level 应该是 INFO"
    assert_equal "false", filtered[0]["is_error"], "INFO 日志的 is_error 应该是 false"
    assert_equal "", filtered[0]["error_category"], "非错误日志的 error_category 应该为空"
  end

  # ============================================================
  # Test 5: 系统指标处理（@SYSTEM 标签处理）
  # ============================================================
  def test_system_label_processing
    conf = %[
      <record>
        hostname "#{Socket.gethostname}"
        service_name "system-monitor"
        log_source "http-input"
      </record>
    ]
    
    d = create_filter(conf)
    time = event_time("2026-01-07 10:00:00 UTC")
    
    input_record = {
      "cpu" => 85,
      "mem" => 60,
      "message" => "system metrics test"
    }
    
    d.run(default_tag: 'system.metrics') do
      d.feed(time, input_record)
    end
    
    filtered = d.filtered_records
    assert_equal 1, filtered.length
    assert_equal "system-monitor", filtered[0]["service_name"]
    assert_equal "http-input", filtered[0]["log_source"]
    assert_equal 85, filtered[0]["cpu"], "应该保留原始 CPU 值"
    assert_equal 60, filtered[0]["mem"], "应该保留原始 MEM 值"
  end

  # ============================================================
  # Test 6: 错误日志告警字段（@APP_ERRORS 标签处理）
  # ============================================================
  def test_error_label_alert_fields
    conf = %[
      <record>
        alert_priority "HIGH"
        troubleshoot_hint "Check FastAPI logs for tracebacks"
      </record>
    ]
    
    d = create_filter(conf)
    time = event_time("2026-01-07 10:00:00 UTC")
    
    d.run(default_tag: 'app.error.detected') do
      d.feed(time, {"log" => "ERROR - something went wrong", "is_error" => "true"})
    end
    
    filtered = d.filtered_records
    assert_equal 1, filtered.length
    assert_equal "HIGH", filtered[0]["alert_priority"], "错误日志的告警优先级应该是 HIGH"
    assert_equal "Check FastAPI logs for tracebacks", filtered[0]["troubleshoot_hint"], "应该有故障排除提示"
  end

  # ============================================================
  # Test 7: 完整 ETL 处理链 - 错误日志
  # ============================================================
  def test_complete_etl_chain_for_error_log
    time = event_time("2026-01-07 10:00:00 UTC")
    
    # Step 1: 添加基础字段
    conf1 = %[
      <record>
        hostname "test-host"
        service_name "fastapi-app"
        etl_node "app-processor"
      </record>
    ]
    d1 = create_filter(conf1)
    d1.run(default_tag: 'fastapi.app') do
      d1.feed(time, {"log" => "ERROR - test error message"})
    end
    
    result1 = d1.filtered_records[0]
    assert_equal "fastapi-app", result1["service_name"]
    
    # Step 2: 错误检测
    conf2 = %[
      enable_ruby true
      <record>
        log_level ${record["log"] && record["log"].include?("ERROR") ? "ERROR" : "INFO"}
        is_error ${record["log"] && record["log"].include?("ERROR") ? "true" : "false"}
        error_category ${if record["log"] && record["log"].include?("ERROR"); record["log"].include?("validation") ? "validation_error" : "general_error"; else; ""; end}
      </record>
    ]
    d2 = create_filter(conf2)
    d2.run(default_tag: 'fastapi.app') do
      d2.feed(time, result1)
    end
    
    result2 = d2.filtered_records[0]
    assert_equal "ERROR", result2["log_level"]
    assert_equal "true", result2["is_error"]
    assert_equal "general_error", result2["error_category"]
    
    # Step 3: 添加告警字段（模拟 @APP_ERRORS 标签处理）
    conf3 = %[
      <record>
        alert_priority "HIGH"
        troubleshoot_hint "Check FastAPI logs for tracebacks"
      </record>
    ]
    d3 = create_filter(conf3)
    d3.run(default_tag: 'app.error.detected') do
      d3.feed(time, result2)
    end
    
    result3 = d3.filtered_records[0]
    assert_equal "HIGH", result3["alert_priority"]
    assert_equal "fastapi-app", result3["service_name"], "应该保留之前添加的字段"
    assert_equal "ERROR", result3["log_level"], "应该保留错误检测结果"
  end

  # ============================================================
  # Test 8: 完整 ETL 处理链 - 正常日志
  # ============================================================
  def test_complete_etl_chain_for_normal_log
    time = event_time("2026-01-07 10:00:00 UTC")
    
    # Step 1: 添加基础字段
    conf1 = %[
      <record>
        hostname "test-host"
        service_name "fastapi-app"
        etl_node "app-processor"
      </record>
    ]
    d1 = create_filter(conf1)
    d1.run(default_tag: 'fastapi.app') do
      d1.feed(time, {"log" => "INFO - Request processed successfully"})
    end
    
    result1 = d1.filtered_records[0]
    
    # Step 2: 错误检测（应该检测为正常日志）
    conf2 = %[
      enable_ruby true
      <record>
        log_level ${record["log"] && record["log"].include?("ERROR") ? "ERROR" : "INFO"}
        is_error ${record["log"] && record["log"].include?("ERROR") ? "true" : "false"}
        error_category ${if record["log"] && record["log"].include?("ERROR"); record["log"].include?("validation") ? "validation_error" : "general_error"; else; ""; end}
      </record>
    ]
    d2 = create_filter(conf2)
    d2.run(default_tag: 'fastapi.app') do
      d2.feed(time, result1)
    end
    
    result2 = d2.filtered_records[0]
    assert_equal "INFO", result2["log_level"]
    assert_equal "false", result2["is_error"], "正常日志不应该被标记为错误"
    assert_equal "", result2["error_category"]
  end

  # ============================================================
  # Helper Methods
  # ============================================================
  private

  def create_filter(conf)
    Fluent::Test::Driver::Filter.new(Fluent::Plugin::RecordTransformerFilter).configure(conf)
  end

  def event_time(str)
    Fluent::EventTime.from_time(Time.parse(str))
  end
end

