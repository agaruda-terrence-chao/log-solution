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

  # ============================================================
  # 配置文件加載輔助函數
  # ============================================================

  # 從配置文件提取特定 label 的 filter 配置
  def load_filter_config_from_file(config_file_path, label_name, filter_tag = nil, filter_type = nil)
    content = File.read(config_file_path)
    
    # 提取 label 區塊
    label_pattern = /<label\s+#{Regexp.escape(label_name)}>(.*?)<\/label>/m
    label_match = content.match(label_pattern)
    
    return nil unless label_match
    
    label_content = label_match[1]
    
    # 如果指定了 filter_tag，只提取該 filter
    if filter_tag
      # 如果指定了 filter_type，需要匹配特定的 filter 類型
      if filter_type
        # 匹配所有符合 filter_tag 的 filter，然後找到符合 filter_type 的
        filter_pattern = /<filter\s+#{Regexp.escape(filter_tag)}>(.*?)<\/filter>/m
        label_content.scan(filter_pattern) do |filter_content|
          # 檢查是否包含指定的 filter_type
          if filter_content[0].include?("@type #{filter_type}")
            return filter_content[0].strip
          end
        end
        return nil
      else
        # 只匹配第一個符合 filter_tag 的 filter
        filter_pattern = /<filter\s+#{Regexp.escape(filter_tag)}>(.*?)<\/filter>/m
        filter_match = label_content.match(filter_pattern)
        return filter_match ? filter_match[1].strip : nil
      end
    else
      # 返回整個 label 內容
      return label_content.strip
    end
  end

  # 從配置文件提取特定 filter 的 <record> 部分
  def extract_record_config_from_filter(filter_config)
    record_pattern = /<record>(.*?)<\/record>/m
    record_match = filter_config.match(record_pattern)
    return record_match ? record_match[1].strip : nil
  end

  # 從配置文件提取 label 中所有符合條件的 filter（按順序）
  def load_all_filters_from_file(config_file_path, label_name, filter_tag = nil, filter_type = nil)
    content = File.read(config_file_path)
    
    # 提取 label 區塊
    label_pattern = /<label\s+#{Regexp.escape(label_name)}>(.*?)<\/label>/m
    label_match = content.match(label_pattern)
    
    return [] unless label_match
    
    label_content = label_match[1]
    filters = []
    
    # 匹配所有符合條件的 filter
    filter_pattern = /<filter\s+#{Regexp.escape(filter_tag || '\*\*')}>(.*?)<\/filter>/m
    label_content.scan(filter_pattern) do |filter_content|
      # 如果指定了 filter_type，只匹配該類型
      if filter_type.nil? || filter_content[0].include?("@type #{filter_type}")
        filters << filter_content[0].strip
      end
    end
    
    filters
  end

  # 從配置文件加載指定索引的 filter（用於加載第二個、第三個 filter）
  def load_filter_by_index_from_file(config_file_path, label_name, filter_tag, filter_index = 0, filter_type = "record_transformer")
    filters = load_all_filters_from_file(config_file_path, label_name, filter_tag, filter_type)
    return nil if filters.empty? || filter_index >= filters.length
    
    filters[filter_index]
  end

  # 從配置文件加載指定索引的 filter 並創建 driver
  def create_filter_driver_by_index_from_config_file(config_file_path, label_name, filter_tag, filter_index = 0, plugin_class = Fluent::Plugin::RecordTransformerFilter, filter_type = "record_transformer")
    filter_config = load_filter_by_index_from_file(config_file_path, label_name, filter_tag, filter_index, filter_type)
    raise "Filter config not found: #{label_name}/#{filter_tag} (index: #{filter_index}, type: #{filter_type})" unless filter_config
    
    # 如果是 record_transformer，提取 <record> 部分
    if filter_type == "record_transformer"
      record_config = extract_record_config_from_filter(filter_config)
      raise "Record config not found in filter" unless record_config
      
      # 為測試環境調整配置（例如替換 Socket.gethostname）
      test_record_config = record_config.gsub(/#\{Socket\.gethostname\}/, "test-host")
      test_record_config = test_record_config.gsub(/"#\{Socket\.gethostname\}"/, '"test-host"')
      
      # 創建測試配置
      test_conf = create_test_filter_config(test_record_config, enable_ruby: true)
      
      # 創建並返回 driver
      create_filter_driver(plugin_class, test_conf)
    else
      # 對於其他類型的 filter（如 grep），直接使用配置
      create_filter_driver(plugin_class, filter_config)
    end
  end

  # 創建完整的 filter 配置（用於測試）
  def create_test_filter_config(record_config, options = {})
    enable_ruby = options[:enable_ruby] != false
    filter_tag = options[:filter_tag] || "**"
    
    conf = ""
    conf += "enable_ruby true\n" if enable_ruby
    conf += "<record>\n"
    conf += record_config
    conf += "\n</record>\n"
    
    conf
  end

  # 從實際配置文件加載並創建測試用的 filter driver
  def create_filter_driver_from_config_file(config_file_path, label_name, filter_tag, plugin_class = Fluent::Plugin::RecordTransformerFilter, filter_type = "record_transformer")
    # 提取 filter 配置（如果指定了 filter_type，會匹配特定類型的 filter）
    filter_config = load_filter_config_from_file(config_file_path, label_name, filter_tag, filter_type)
    raise "Filter config not found: #{label_name}/#{filter_tag} (type: #{filter_type})" unless filter_config
    
    # 如果是 record_transformer，提取 <record> 部分
    if filter_type == "record_transformer"
      record_config = extract_record_config_from_filter(filter_config)
      raise "Record config not found in filter" unless record_config
      
      # 為測試環境調整配置（例如替換 Socket.gethostname）
      # 注意：在配置字符串中，Socket.gethostname 會被替換為 test-host
      # 匹配兩種格式：#{Socket.gethostname} 和 "#{Socket.gethostname}"
      test_record_config = record_config.gsub(/#\{Socket\.gethostname\}/, "test-host")
      test_record_config = test_record_config.gsub(/"#\{Socket\.gethostname\}"/, '"test-host"')
      
      # 創建測試配置
      test_conf = create_test_filter_config(test_record_config, enable_ruby: true)
      
      # 創建並返回 driver
      create_filter_driver(plugin_class, test_conf)
    else
      # 對於其他類型的 filter（如 grep），直接使用配置
      create_filter_driver(plugin_class, filter_config)
    end
  end

  # 加載微服務配置文件的路徑輔助函數: service-fastapi-app-2.conf
  def get_service_config_path(service_name)
    config_file = File.join(__dir__, '..', 'conf.d', "service-#{service_name}-2.conf")
    unless File.exist?(config_file)
      raise "Config file not found: #{config_file}"
    end
    config_file
  end

  # 從配置文件提取 grep filter 配置
  def extract_grep_filter_config(config_file_path, label_name, filter_tag = nil)
    label_content = load_filter_config_from_file(config_file_path, label_name)
    return nil unless label_content
    
    # 提取所有 filter（匹配 <filter tag> 到 </filter>）
    # 如果指定了 filter_tag，使用它；否则匹配任何 filter
    if filter_tag
      tag_pattern = Regexp.escape(filter_tag)
      grep_pattern = /<filter\s+#{tag_pattern}>(.*?)<\/filter>/m
    else
      grep_pattern = /<filter\s+[^>]+>(.*?)<\/filter>/m
    end
    
    # 查找所有匹配的 filter
    label_content.scan(grep_pattern) do |filter_content|
      # 檢查是否為 grep filter
      if filter_content[0].include?("@type grep")
        # 返回完整的 filter 配置（包含原始 tag）
        match_result = label_content.match(/<filter\s+([^>]+)>(.*?)<\/filter>/m)
        if match_result && match_result[2].include?("@type grep")
          return "<filter #{match_result[1]}>#{match_result[2]}</filter>"
        end
      end
    end
    
    # 如果沒找到，嘗試匹配所有 filter 並找到 grep
    label_content.scan(/<filter\s+([^>]+)>(.*?)<\/filter>/m) do |tag, content|
      if content.include?("@type grep")
        return "<filter #{tag}>#{content}</filter>"
      end
    end
    
    return nil
  end
end

# 包含到所有測試類
Test::Unit::TestCase.include(FluentdTestHelper)

