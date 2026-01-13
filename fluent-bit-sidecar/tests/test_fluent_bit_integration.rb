#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# test_fluent_bit_integration.rb - Fluent Bit 集成測試
# 通過 HTTP 發送數據並驗證 Fluent Bit 的處理

require 'test/unit'
require 'net/http'
require 'json'
require 'timeout'

class FluentBitIntegrationTest < Test::Unit::TestCase
  
  def setup
    @order_app_url = URI('http://localhost:8888')
    @user_app_url = URI('http://localhost:8889')
    @timeout = 5
  end

  # ============================================================
  # Test 1: Order App HTTP Input 可用性
  # ============================================================
  def test_order_app_http_input_available
    http = Net::HTTP.new(@order_app_url.host, @order_app_url.port)
    http.open_timeout = @timeout
    http.read_timeout = @timeout
    
    begin
      response = http.get('/')
      # HTTP input 可能返回 400, 404 或 405，這表示服務正在運行
      assert [400, 404, 405, 200].include?(response.code.to_i), "Order App HTTP input 應該響應 (狀態碼: #{response.code})"
    rescue Errno::ECONNREFUSED, Timeout::Error, SocketError => e
      skip "Order App HTTP input 不可用: #{e.message}"
    end
  end

  # ============================================================
  # Test 2: User App HTTP Input 可用性
  # ============================================================
  def test_user_app_http_input_available
    http = Net::HTTP.new(@user_app_url.host, @user_app_url.port)
    http.open_timeout = @timeout
    http.read_timeout = @timeout
    
    begin
      response = http.get('/')
      # HTTP input 可能返回 400, 404 或 405，這表示服務正在運行
      assert [400, 404, 405, 200].include?(response.code.to_i), "User App HTTP input 應該響應 (狀態碼: #{response.code})"
    rescue Errno::ECONNREFUSED, Timeout::Error, SocketError => e
      skip "User App HTTP input 不可用: #{e.message}"
    end
  end

  # ============================================================
  # Test 3: Order App 日誌發送測試
  # ============================================================
  def test_order_app_log_sending
    http = Net::HTTP.new(@order_app_url.host, @order_app_url.port)
    http.open_timeout = @timeout
    http.read_timeout = @timeout
    
    test_log = {
      "message" => "[ORDER] Test order log",
      "level" => "INFO",
      "order_id" => "ORD-TEST-001",
      "user_id" => "USER-TEST-001",
      "amount" => "99.99"
    }
    
    begin
      # 使用 '/' 作為路徑（Fluent Bit HTTP input 接受任何路徑）
      path = @order_app_url.path.empty? ? '/' : @order_app_url.path
      request = Net::HTTP::Post.new(path)
      request['Content-Type'] = 'application/json'
      request.body = test_log.to_json
      
      response = http.request(request)
      
      # Fluent Bit HTTP input 通常返回 200 或 201
      assert [200, 201].include?(response.code.to_i), "應該成功發送日誌 (狀態碼: #{response.code})"
    rescue Errno::ECONNREFUSED, Timeout::Error, SocketError => e
      skip "Order App HTTP input 不可用: #{e.message}"
    end
  end

  # ============================================================
  # Test 4: User App 日誌發送測試
  # ============================================================
  def test_user_app_log_sending
    http = Net::HTTP.new(@user_app_url.host, @user_app_url.port)
    http.open_timeout = @timeout
    http.read_timeout = @timeout
    
    test_log = {
      "message" => "[USER] Test user log",
      "level" => "INFO",
      "user_id" => "USER-TEST-002",
      "action" => "login",
      "ip_address" => "192.168.1.100"
    }
    
    begin
      # 使用 '/' 作為路徑（Fluent Bit HTTP input 接受任何路徑）
      path = @user_app_url.path.empty? ? '/' : @user_app_url.path
      request = Net::HTTP::Post.new(path)
      request['Content-Type'] = 'application/json'
      request.body = test_log.to_json
      
      response = http.request(request)
      
      # Fluent Bit HTTP input 通常返回 200 或 201
      assert [200, 201].include?(response.code.to_i), "應該成功發送日誌 (狀態碼: #{response.code})"
    rescue Errno::ECONNREFUSED, Timeout::Error, SocketError => e
      skip "User App HTTP input 不可用: #{e.message}"
    end
  end

  # ============================================================
  # Test 5: Order App 錯誤日誌發送測試
  # ============================================================
  def test_order_app_error_log_sending
    http = Net::HTTP.new(@order_app_url.host, @order_app_url.port)
    http.open_timeout = @timeout
    http.read_timeout = @timeout
    
    test_log = {
      "message" => "[ORDER] Payment failed",
      "level" => "ERROR",
      "order_id" => "ORD-ERROR-001"
    }
    
    begin
      # 使用 '/' 作為路徑（Fluent Bit HTTP input 接受任何路徑）
      path = @order_app_url.path.empty? ? '/' : @order_app_url.path
      request = Net::HTTP::Post.new(path)
      request['Content-Type'] = 'application/json'
      request.body = test_log.to_json
      
      response = http.request(request)
      
      assert [200, 201].include?(response.code.to_i), "應該成功發送錯誤日誌 (狀態碼: #{response.code})"
    rescue Errno::ECONNREFUSED, Timeout::Error, SocketError => e
      skip "Order App HTTP input 不可用: #{e.message}"
    end
  end

  # ============================================================
  # Test 6: User App 錯誤日誌發送測試
  # ============================================================
  def test_user_app_error_log_sending
    http = Net::HTTP.new(@user_app_url.host, @user_app_url.port)
    http.open_timeout = @timeout
    http.read_timeout = @timeout
    
    test_log = {
      "message" => "[USER] Authentication failed",
      "level" => "ERROR",
      "user_id" => "USER-ERROR-001"
    }
    
    begin
      # 使用 '/' 作為路徑（Fluent Bit HTTP input 接受任何路徑）
      path = @user_app_url.path.empty? ? '/' : @user_app_url.path
      request = Net::HTTP::Post.new(path)
      request['Content-Type'] = 'application/json'
      request.body = test_log.to_json
      
      response = http.request(request)
      
      assert [200, 201].include?(response.code.to_i), "應該成功發送錯誤日誌 (狀態碼: #{response.code})"
    rescue Errno::ECONNREFUSED, Timeout::Error, SocketError => e
      skip "User App HTTP input 不可用: #{e.message}"
    end
  end

  # ============================================================
  # Test 7: 格式錯誤日誌處理測試
  # ============================================================
  def test_malformed_log_handling
    http = Net::HTTP.new(@order_app_url.host, @order_app_url.port)
    http.open_timeout = @timeout
    http.read_timeout = @timeout
    
    # 缺少必需字段的日誌
    test_log = {
      "order_id" => "ORD-MALFORMED-001"
      # 缺少 message 和 level
    }
    
    begin
      # 使用 '/' 作為路徑（Fluent Bit HTTP input 接受任何路徑）
      path = @order_app_url.path.empty? ? '/' : @order_app_url.path
      request = Net::HTTP::Post.new(path)
      request['Content-Type'] = 'application/json'
      request.body = test_log.to_json
      
      response = http.request(request)
      
      # Fluent Bit 應該接受請求（格式驗證在 Fluentd 中進行）
      assert [200, 201].include?(response.code.to_i), "應該接受格式錯誤的日誌 (狀態碼: #{response.code})"
    rescue Errno::ECONNREFUSED, Timeout::Error, SocketError => e
      skip "Order App HTTP input 不可用: #{e.message}"
    end
  end
end
