#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# test_fluent_bit_config.rb - Fluent Bit 配置文件測試
# 測試 fluent-bit.conf 的語法和配置正確性

require 'test/unit'
require 'open3'

class FluentBitConfigTest < Test::Unit::TestCase
  
  def setup
    @config_file = File.expand_path(File.join(__dir__, '..', 'fluent-bit.conf'))
    @fluent_bit_bin = ENV['FLUENT_BIT_BIN'] || 'fluent-bit'
  end

  # ============================================================
  # Test 1: 配置文件是否存在
  # ============================================================
  def test_config_file_exists
    assert File.exist?(@config_file), "配置文件應該存在: #{@config_file}"
  end

  # ============================================================
  # Test 2: 配置文件語法驗證（使用 fluent-bit --dry-run）
  # ============================================================
  def test_config_syntax_validation
    return unless File.exist?(@config_file)
    return unless system("which #{@fluent_bit_bin} > /dev/null 2>&1") || system("docker exec log-solution-fluentd-3-fluent-bit-sidecar which fluent-bit > /dev/null 2>&1")
    
    # 使用 fluent-bit 的 --dry-run 模式驗證配置
    cmd = "#{@fluent_bit_bin} --dry-run -c #{@config_file} 2>&1"
    stdout, stderr, status = Open3.capture3(cmd)
    
    # 檢查是否有錯誤
    if status.exitstatus != 0
      puts "Fluent Bit 配置驗證失敗:"
      puts stdout
      puts stderr
    end
    
    assert status.success?, "配置文件語法應該正確 (退出碼: #{status.exitstatus})"
    assert_match(/configuration file/, stdout + stderr, "應該有配置驗證輸出")
  end

  # ============================================================
  # Test 3: 配置文件結構完整性
  # ============================================================
  def test_config_file_structure
    return unless File.exist?(@config_file)
    
    content = File.read(@config_file, encoding: 'UTF-8')
    
    # 檢查必需的 sections
    assert_match(/\[SERVICE\]/, content, "應該有 [SERVICE] 部分")
    assert_match(/\[INPUT\]/, content, "應該有 [INPUT] 部分")
    assert_match(/\[FILTER\]/, content, "應該有 [FILTER] 部分")
    assert_match(/\[OUTPUT\]/, content, "應該有 [OUTPUT] 部分")
    
    # 檢查 HTTP input 配置
    assert_match(/Name\s+http/, content, "應該有 HTTP input")
    assert_match(/Port\s+8888/, content, "應該有端口 8888 的 HTTP input (Order App)")
    assert_match(/Port\s+8889/, content, "應該有端口 8889 的 HTTP input (User App)")
    
    # 檢查 storage 配置
    assert_match(/storage\.path/, content, "應該有 storage.path 配置")
    assert_match(/storage\.max_chunks_up/, content, "應該有 storage.max_chunks_up 配置")
    assert_match(/storage\.backlog\.mem_limit/, content, "應該有 storage.backlog.mem_limit 配置")
    
    # 檢查 output 配置
    assert_match(/Name\s+forward/, content, "應該有 forward output")
    assert_match(/Host\s+fluentd/, content, "應該配置發送到 fluentd")
    assert_match(/Port\s+24224/, content, "應該配置端口 24224")
  end

  # ============================================================
  # Test 4: HTTP Input 配置驗證
  # ============================================================
  def test_http_input_configuration
    return unless File.exist?(@config_file)
    
    content = File.read(@config_file, encoding: 'UTF-8')
    
    # 檢查 Order App HTTP input (端口 8888)
    order_input_pattern = /\[INPUT\].*?Name\s+http.*?Port\s+8888.*?Tag\s+order\.log/m
    assert_match(order_input_pattern, content, "應該有 Order App 的 HTTP input 配置 (端口 8888, tag: order.log)")
    
    # 檢查 User App HTTP input (端口 8889)
    user_input_pattern = /\[INPUT\].*?Name\s+http.*?Port\s+8889.*?Tag\s+user\.log/m
    assert_match(user_input_pattern, content, "應該有 User App 的 HTTP input 配置 (端口 8889, tag: user.log)")
    
    # 檢查 storage.type filesystem
    assert_match(/storage\.type\s+filesystem/, content, "HTTP input 應該啟用 filesystem storage")
  end

  # ============================================================
  # Test 5: Filter 配置驗證
  # ============================================================
  def test_filter_configuration
    return unless File.exist?(@config_file)
    
    content = File.read(@config_file, encoding: 'UTF-8')
    
    # 檢查 Order App filter
    order_filter_pattern = /\[FILTER\].*?Name\s+modify.*?Match\s+order\.log.*?Add\s+service_name\s+order-app/m
    assert_match(order_filter_pattern, content, "應該有 Order App 的 modify filter")
    
    # 檢查 User App filter
    user_filter_pattern = /\[FILTER\].*?Name\s+modify.*?Match\s+user\.log.*?Add\s+service_name\s+user-app/m
    assert_match(user_filter_pattern, content, "應該有 User App 的 modify filter")
    
    # 檢查 Rename 操作
    assert_match(/Rename\s+message\s+log/, content, "應該有 message 到 log 的字段重命名")
  end

  # ============================================================
  # Test 6: Storage 配置驗證
  # ============================================================
  def test_storage_configuration
    return unless File.exist?(@config_file)
    
    content = File.read(@config_file, encoding: 'UTF-8')
    
    # 檢查 storage.path
    assert_match(/storage\.path\s+\/var\/log\/flb-storage\//, content, "應該配置 storage.path")
    
    # 檢查 storage.max_chunks_up (約 50MB)
    assert_match(/storage\.max_chunks_up\s+25/, content, "應該配置 storage.max_chunks_up 為 25 (約 50MB)")
    
    # 檢查 storage.backlog.mem_limit (5MB)
    assert_match(/storage\.backlog\.mem_limit\s+5M/, content, "應該配置 storage.backlog.mem_limit 為 5M")
  end

  # ============================================================
  # Test 7: Output 配置驗證
  # ============================================================
  def test_output_configuration
    return unless File.exist?(@config_file)
    
    content = File.read(@config_file, encoding: 'UTF-8')
    
    # 檢查 forward output
    output_pattern = /\[OUTPUT\].*?Name\s+forward.*?Host\s+fluentd.*?Port\s+24224/m
    assert_match(output_pattern, content, "應該有 forward output 配置")
    
    # 檢查壓縮配置
    assert_match(/Compress\s+gzip/, content, "應該啟用 gzip 壓縮")
    
    # 檢查重試配置
    assert_match(/Retry_Limit\s+3/, content, "應該配置重試限制")
    assert_match(/Require_ack_response\s+True/, content, "應該要求確認響應")
  end

  # ============================================================
  # Test 8: 配置參數值驗證
  # ============================================================
  def test_config_parameter_values
    return unless File.exist?(@config_file)
    
    content = File.read(@config_file, encoding: 'UTF-8')
    
    # 驗證 SERVICE 部分的配置
    assert_match(/Flush\s+5/, content, "Flush 間隔應該是 5 秒")
    assert_match(/Log_Level\s+info/, content, "日誌級別應該是 info")
    assert_match(/Daemon\s+off/, content, "應該以非守護進程模式運行")
  end
end
