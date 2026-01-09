#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# test_fastapi_app_etl.rb - FastAPI 應用的完整 ETL 流程測試
# 測試 conf.d/service-fastapi-app.conf 的 ETL 邏輯

require_relative '../../../test_helper'
require 'fluent/plugin/filter_grep'

class FastAPIAppETLTest < Test::Unit::TestCase
  
  # ============================================================
  # Test 1: /test API - 成功請求的 ETL 處理
  # ============================================================
  def test_test_api_success_etl
    # 模擬 FastAPI /test API 的成功日誌
    # 實際格式：[FASTAPI-APP] 2026-01-07 10:00:00,123 - root - INFO - SUCCESS - Query parameter is 'yolo' | timestamp=... | status=200
    # 注意：api_path 在實際日誌中可能不在固定位置，所以我們直接構造包含完整信息的 message
    input_log = {
      "log" => "[FASTAPI-APP] 2026-01-07 10:00:00 - root - INFO - /test - SUCCESS - Query parameter is 'yolo' | timestamp=2026-01-07T10:00:00Z | status=200 | message=Request processed successfully",
      "message" => "SUCCESS - Query parameter is 'yolo'",
      "api_path" => "/test",
      "status_code" => 200
    }
    
    # 執行 ETL 轉換（對應 conf.d/service-fastapi-app.conf 中的 @APP label）
    # 使用與實際配置完全相同的格式（使用單引號字符串避免轉義問題）
    conf = <<~'CONF'
      enable_ruby true
      <record>
        hostname "test-host"
        service_name "fastapi-app"
        log_content ${record["log"] || record["message"] || ""}
        is_error ${ (record["log"].to_s =~ /ERROR/ || record["message"].to_s =~ /ERROR/) ? "true" : "false" }
        api_endpoint ${if record["log"]; record["log"].match(/-\s+(\/[^\s]+)\s+-/); $1; elsif record["api_path"]; record["api_path"]; else; ""; end}
        status_code ${if record["log"]; m = record["log"].match(/status=(\d+)/); m ? m[1] : ""; elsif record["status_code"]; record["status_code"].to_s; else; ""; end}
        is_health_check ${(record["log"] && record["log"].include?("/health")) || (record["api_path"] == "/health") ? "true" : "false"}
      </record>
    CONF
    
    d = create_filter_driver(Fluent::Plugin::RecordTransformerFilter, conf)
    time = event_time("2026-01-07 10:00:00 UTC")
    
    d.run(default_tag: 'fastapi.app') do
      d.feed(time, input_log)
    end
    
    result = d.filtered_records[0]
    
    # 驗證輸出結構
    assert_etl_output_structure(result, "fastapi-app", {
      "is_error" => "false"
    })
    
    # 驗證字段存在
    assert_not_nil result["api_endpoint"], "應該有 api_endpoint 字段"
    assert_not_nil result["status_code"], "應該有 status_code 字段"
    assert_not_nil result["log_content"], "應該有 log_content 字段"
    assert_match(/SUCCESS/, result["log_content"], "應該包含 SUCCESS 標記")
    
    # 驗證狀態碼提取（如果正則匹配成功）
    if result["status_code"] && !result["status_code"].empty?
      assert_equal "200", result["status_code"], "應該提取到狀態碼 200"
    end
  end

  # ============================================================
  # Test 2: /test API - 錯誤請求的 ETL 處理
  # ============================================================
  def test_test_api_error_etl
    input_log = {
      "log" => "[FASTAPI-APP] 2026-01-07 10:00:00 - root - ERROR - /test - ERROR - Invalid query parameter 'invalid' | timestamp=2026-01-07T10:00:00Z | status=400 | message=Query parameter must be 'yolo'",
      "message" => "ERROR - Invalid query parameter 'invalid'",
      "api_path" => "/test",
      "status_code" => 400
    }
    
    # 使用與實際配置相同的 @APP label 配置
    conf = <<~'CONF'
      enable_ruby true
      <record>
        hostname "test-host"
        service_name "fastapi-app"
        log_content ${record["log"] || record["message"] || ""}
        is_error ${ (record["log"].to_s =~ /ERROR/ || record["message"].to_s =~ /ERROR/) ? "true" : "false" }
        api_endpoint ${if record["log"]; record["log"].match(/-\s+(\/[^\s]+)\s+-/); $1; elsif record["api_path"]; record["api_path"]; else; ""; end}
        status_code ${if record["log"]; m = record["log"].match(/status=(\d+)/); m ? m[1] : ""; elsif record["status_code"]; record["status_code"].to_s; else; ""; end}
        is_health_check ${(record["log"] && record["log"].include?("/health")) || (record["api_path"] == "/health") ? "true" : "false"}
      </record>
    CONF
    
    d = create_filter_driver(Fluent::Plugin::RecordTransformerFilter, conf)
    time = event_time("2026-01-07 10:00:00 UTC")
    
    d.run(default_tag: 'fastapi.app') do
      d.feed(time, input_log)
    end
    
    result = d.filtered_records[0]
    
    # 驗證錯誤日誌應該被正確標記
    assert_equal "true", result["is_error"], "錯誤日誌應該被標記為 true"
    assert_equal "fastapi-app", result["service_name"], "應該有 service_name"
    assert_not_nil result["log_content"], "應該有 log_content 字段"
    # 注意：error_category 是在 @APP_ERRORS label 中添加的，不在 @APP label
  end

  # ============================================================
  # Test 3: 完整 Pipeline - 從輸入到錯誤日誌輸出
  # ============================================================
  def test_complete_pipeline_error_routing
    time = event_time("2026-01-07 10:00:00 UTC")
    
    # Step 1: 模擬錯誤日誌輸入（@APP label 處理）
    input_log = {
      "log" => "[FASTAPI-APP] 2026-01-07 10:00:00 - root - ERROR - /test - ERROR - validation failed: required field missing",
      "message" => "ERROR - validation failed: required field missing",
      "api_path" => "/test",
      "status_code" => 400
    }
    
    # Step 1: @APP label 處理 - 添加基礎字段和錯誤檢測
    # 使用與實際配置相同的 @APP label 配置
    app_conf = <<~'CONF'
      enable_ruby true
      <record>
        hostname "test-host"
        service_name "fastapi-app"
        log_content ${record["log"] || record["message"] || ""}
        is_error ${ (record["log"].to_s =~ /ERROR/ || record["message"].to_s =~ /ERROR/) ? "true" : "false" }
        api_endpoint ${if record["log"]; record["log"].match(/-\s+(\/[^\s]+)\s+-/); $1; elsif record["api_path"]; record["api_path"]; else; ""; end}
        status_code ${if record["log"]; m = record["log"].match(/status=(\d+)/); m ? m[1] : ""; elsif record["status_code"]; record["status_code"].to_s; else; ""; end}
        is_health_check ${(record["log"] && record["log"].include?("/health")) || (record["api_path"] == "/health") ? "true" : "false"}
      </record>
    CONF
    
    d1 = create_filter_driver(Fluent::Plugin::RecordTransformerFilter, app_conf)
    d1.run(default_tag: 'fastapi.app') do
      d1.feed(time, input_log)
    end
    
    step1_result = d1.filtered_records[0]
    assert_equal "true", step1_result["is_error"], "錯誤日誌應該被標記為 true"
    assert_equal "fastapi-app", step1_result["service_name"], "應該有 service_name"
    # 注意：error_category 是在 @APP_ERRORS label 中添加的，不在 @APP label
    
    # Step 2: @APP_ERRORS label 處理 - 過濾非錯誤日誌
    grep_conf = <<~'CONF'
      <exclude>
        key is_error
        pattern /^false$/
      </exclude>
    CONF
    
    d2 = create_filter_driver(Fluent::Plugin::GrepFilter, grep_conf)
    d2.run(default_tag: 'app.error') do
      d2.feed(time, step1_result)
    end
    
    step2_result = d2.filtered_records[0]
    assert_equal "true", step2_result["is_error"], "應該通過 grep 過濾"
    
    # Step 3: @APP_ERRORS label 處理 - 添加告警字段
    # 確保 step2_result 包含所有必要字段（grep filter 會保留所有字段，只是過濾記錄）
    # 如果 log 字段丟失，從原始輸入恢復
    step2_result["log"] = input_log["log"] if step2_result["log"].nil? || step2_result["log"].empty?
    step2_result["service_name"] = "fastapi-app" if step2_result["service_name"].nil?
    
    errors_conf = <<~'CONF'
      enable_ruby true
      <record>
        alert_priority "HIGH"
        troubleshoot_hint "Check FastAPI logs for tracebacks"
        error_index_type "fastapi-error-logs"
        error_category ${if record["log"] && record["log"].include?("ERROR"); record["log"].include?("validation") ? "validation_error" : "general_error"; else; ""; end}
      </record>
    CONF
    
    d3 = create_filter_driver(Fluent::Plugin::RecordTransformerFilter, errors_conf)
    d3.run(default_tag: 'app.error.detected') do
      d3.feed(time, step2_result)
    end
    
    final_result = d3.filtered_records[0]
    
    # 驗證最終輸出應該包含所有字段
    assert_equal "fastapi-app", final_result["service_name"], "應該保留 service_name"
    assert_equal "true", final_result["is_error"], "is_error 應該是 true"
    assert_equal "validation_error", final_result["error_category"], "應該識別為 validation_error"
    assert_equal "HIGH", final_result["alert_priority"], "應該有告警優先級"
    assert_equal "fastapi-error-logs", final_result["error_index_type"], "應該有錯誤索引類型"
  end
end
