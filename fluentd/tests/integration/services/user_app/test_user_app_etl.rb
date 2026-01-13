#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# test_user_app_etl.rb - User App 的完整 ETL 流程測試
# 測試 conf.d/service-user-app-3.conf 的 ETL 邏輯

require_relative '../../../test_helper'
require 'fluent/plugin/filter_grep'

class UserAppETLTest < Test::Unit::TestCase
  
  # 加載配置文件路徑
  def setup
    @config_file = File.join(__dir__, '..', '..', '..', '..', 'conf.d', 'service-user-app-3.conf')
    unless File.exist?(@config_file)
      raise "Config file not found: #{@config_file}"
    end
  end
  
  # ============================================================
  # Test 1: 正常日誌處理（格式正確且 level = INFO）
  # ============================================================
  def test_normal_log_processing
    input_log = {
      "log" => "[USER] User login successful",
      "message" => "[USER] User login successful",
      "level" => "INFO",
      "user_id" => "USER-001",
      "action" => "login",
      "ip_address" => "192.168.1.100"
    }
    
    # 從配置文件加載 @USER_APP label 的第一個 filter
    d = create_filter_driver_from_config_file(@config_file, "@USER_APP", "user.log")
    time = event_time("2026-01-13 10:00:00 UTC")
    
    d.run(default_tag: 'user.log') do
      d.feed(time, input_log)
    end
    
    result = d.filtered_records[0]
    
    # 驗證輸出結構
    assert_not_nil result, "記錄不應該為空"
    assert_equal "user-app", result["service_name"], "service_name 應該是 user-app"
    assert_equal "INFO", result["log_level"], "log_level 應該是 INFO"
    assert_equal "true", result["format_valid"], "格式應該驗證通過"
    assert_equal "false", result["is_error"], "正常日誌 is_error 應該是 false"
    assert_equal "USER-001", result["user_id"], "應該提取 user_id"
    assert_equal "login", result["action"], "應該提取 action"
    assert_equal "192.168.1.100", result["ip_address"], "應該提取 ip_address"
  end

  # ============================================================
  # Test 2: 錯誤日誌處理（level = ERROR）
  # ============================================================
  def test_error_log_processing
    input_log = {
      "log" => "[USER] Authentication failed",
      "message" => "[USER] Authentication failed",
      "level" => "ERROR",
      "user_id" => "USER-002"
    }
    
    # Step 1: 第一個 filter 處理
    d1 = create_filter_driver_from_config_file(@config_file, "@USER_APP", "user.log")
    time = event_time("2026-01-13 10:00:00 UTC")
    
    d1.run(default_tag: 'user.log') do
      d1.feed(time, input_log)
    end
    
    step1_result = d1.filtered_records[0]
    assert_equal "true", step1_result["is_error"], "ERROR 級別日誌應該被標記為 true"
    assert_equal "true", step1_result["format_valid"], "格式應該驗證通過"
    
    # Step 2: 從配置文件加載第二個 filter（should_route_to_error）
    # filter_index=1 表示第二個 filter（索引從 0 開始）
    d2 = create_filter_driver_by_index_from_config_file(@config_file, "@USER_APP", "user.log", 1, Fluent::Plugin::RecordTransformerFilter, "record_transformer")
    
    d2.run(default_tag: 'user.log') do
      d2.feed(time, step1_result)
    end
    
    step2_result = d2.filtered_records[0]
    assert_equal "true", step2_result["should_route_to_error"], "ERROR 日誌應該路由到錯誤索引"
  end

  # ============================================================
  # Test 3: 格式錯誤日誌處理（缺少必需字段）
  # ============================================================
  def test_format_error_log_processing
    input_log = {
      "user_id" => "USER-003"
      # 缺少 message/log 和 level
    }
    
    d = create_filter_driver_from_config_file(@config_file, "@USER_APP", "user.log")
    time = event_time("2026-01-13 10:00:00 UTC")
    
    d.run(default_tag: 'user.log') do
      d.feed(time, input_log)
    end
    
    result = d.filtered_records[0]
    assert_equal "false", result["format_valid"], "格式驗證應該失敗"
    
    # 從配置文件加載第二個 filter（should_route_to_error）
    d2 = create_filter_driver_by_index_from_config_file(@config_file, "@USER_APP", "user.log", 1, Fluent::Plugin::RecordTransformerFilter, "record_transformer")
    d2.run(default_tag: 'user.log') do
      d2.feed(time, result)
    end
    
    step2_result = d2.filtered_records[0]
    assert_equal "true", step2_result["should_route_to_error"], "格式錯誤應該路由到錯誤索引"
  end

  # ============================================================
  # Test 4: 正常日誌路由到 @USER_APP_NORMAL
  # ============================================================
  def test_normal_log_routing
    input_log = {
      "log" => "[USER] User profile updated",
      "message" => "[USER] User profile updated",
      "level" => "INFO",
      "user_id" => "USER-004"
    }
    
    # 處理並添加 should_route_to_error
    d1 = create_filter_driver_from_config_file(@config_file, "@USER_APP", "user.log")
    time = event_time("2026-01-13 10:00:00 UTC")
    
    d1.run(default_tag: 'user.log') do
      d1.feed(time, input_log)
    end
    
    step1_result = d1.filtered_records[0]
    
    # 從配置文件加載第二個 filter（should_route_to_error）
    d2 = create_filter_driver_by_index_from_config_file(@config_file, "@USER_APP", "user.log", 1, Fluent::Plugin::RecordTransformerFilter, "record_transformer")
    d2.run(default_tag: 'user.log') do
      d2.feed(time, step1_result)
    end
    
    step2_result = d2.filtered_records[0]
    assert_equal "false", step2_result["should_route_to_error"], "正常日誌不應該路由到錯誤索引"
    
    # 測試 grep filter（@USER_APP_NORMAL 中的過濾）
    grep_conf = extract_grep_filter_config(@config_file, "@USER_APP_NORMAL")
    raise "Grep filter config not found" unless grep_conf
    
    d3 = create_filter_driver(Fluent::Plugin::GrepFilter, grep_conf)
    d3.run(default_tag: 'user.log') do
      d3.feed(time, step2_result)
    end
    
    step3_result = d3.filtered_records[0]
    assert_not_nil step3_result, "正常日誌應該通過 grep 過濾"
    assert_equal "false", step3_result["should_route_to_error"]
  end

  # ============================================================
  # Test 5: 錯誤日誌路由到 @USER_APP_ERRORS
  # ============================================================
  def test_error_log_routing
    input_log = {
      "log" => "[USER] Permission denied",
      "message" => "[USER] Permission denied",
      "level" => "ERROR",
      "user_id" => "USER-005"
    }
    
    # 處理並添加 should_route_to_error
    d1 = create_filter_driver_from_config_file(@config_file, "@USER_APP", "user.log")
    time = event_time("2026-01-13 10:00:00 UTC")
    
    d1.run(default_tag: 'user.log') do
      d1.feed(time, input_log)
    end
    
    step1_result = d1.filtered_records[0]
    
    # 從配置文件加載第二個 filter（should_route_to_error）
    d2 = create_filter_driver_by_index_from_config_file(@config_file, "@USER_APP", "user.log", 1, Fluent::Plugin::RecordTransformerFilter, "record_transformer")
    d2.run(default_tag: 'user.log') do
      d2.feed(time, step1_result)
    end
    
    step2_result = d2.filtered_records[0]
    assert_equal "true", step2_result["should_route_to_error"], "錯誤日誌應該路由到錯誤索引"
    
    # 測試 grep filter（@USER_APP_ERRORS 中的過濾）
    grep_conf = extract_grep_filter_config(@config_file, "@USER_APP_ERRORS")
    raise "Grep filter config not found" unless grep_conf
    
    d3 = create_filter_driver(Fluent::Plugin::GrepFilter, grep_conf)
    d3.run(default_tag: 'user.log') do
      d3.feed(time, step2_result)
    end
    
    step3_result = d3.filtered_records[0]
    assert_not_nil step3_result, "錯誤日誌應該通過 grep 過濾"
    assert_equal "true", step3_result["should_route_to_error"]
    
    # 測試錯誤分類 filter（@USER_APP_ERRORS 中的 record_transformer）
    d4 = create_filter_driver_from_config_file(@config_file, "@USER_APP_ERRORS", "user.log", Fluent::Plugin::RecordTransformerFilter, "record_transformer")
    d4.run(default_tag: 'user.log') do
      d4.feed(time, step3_result)
    end
    
    final_result = d4.filtered_records[0]
    assert_equal "business_error", final_result["error_type"], "ERROR 級別應該識別為 business_error"
    assert_equal "HIGH", final_result["alert_priority"], "應該有告警優先級"
    assert_not_nil final_result["error_message"], "應該有錯誤消息"
  end

  # ============================================================
  # Test 6: 格式錯誤日誌的錯誤分類
  # ============================================================
  def test_format_error_classification
    input_log = {
      "user_id" => "USER-006"
      # 缺少必需字段
    }
    
    d1 = create_filter_driver_from_config_file(@config_file, "@USER_APP", "user.log")
    time = event_time("2026-01-13 10:00:00 UTC")
    
    d1.run(default_tag: 'user.log') do
      d1.feed(time, input_log)
    end
    
    step1_result = d1.filtered_records[0]
    assert_equal "false", step1_result["format_valid"], "格式驗證應該失敗"
    
    # 從配置文件加載第二個 filter（should_route_to_error）
    d2 = create_filter_driver_by_index_from_config_file(@config_file, "@USER_APP", "user.log", 1, Fluent::Plugin::RecordTransformerFilter, "record_transformer")
    d2.run(default_tag: 'user.log') do
      d2.feed(time, step1_result)
    end
    
    step2_result = d2.filtered_records[0]
    
    # 測試錯誤分類
    d3 = create_filter_driver_from_config_file(@config_file, "@USER_APP_ERRORS", "user.log", Fluent::Plugin::RecordTransformerFilter, "record_transformer")
    d3.run(default_tag: 'user.log') do
      d3.feed(time, step2_result)
    end
    
    final_result = d3.filtered_records[0]
    assert_equal "format_error", final_result["error_type"], "格式錯誤應該識別為 format_error"
    assert_match(/format validation failed/, final_result["error_message"], "錯誤消息應該包含格式驗證失敗信息")
  end

  # ============================================================
  # Test 7: 異常輸入處理
  # ============================================================
  def test_error_handling_malformed_input
    input_log = {
      "log" => nil,
      "message" => "",
      "level" => nil
    }
    
    d = create_filter_driver_from_config_file(@config_file, "@USER_APP", "user.log")
    time = event_time("2026-01-13 10:00:00 UTC")
    
    # 應該不會拋出異常，配置文件中的 rescue 應該處理
    assert_nothing_raised do
      d.run(default_tag: 'user.log') do
        d.feed(time, input_log)
      end
    end
    
    result = d.filtered_records[0]
    assert_not_nil result, "即使輸入異常，也應該產生輸出記錄"
    assert_equal "user-app", result["service_name"]
    assert_equal "false", result["format_valid"], "格式驗證應該失敗"
  end
end
