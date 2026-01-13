import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// 自定义指标
const errorRate = new Rate('errors');
const responseTime = new Trend('response_time');
const orderCreatedRate = new Rate('order_created');
const orderErrorRate = new Rate('order_errors');

export const options = {
  scenarios: {
    constant_request_rate: {
      executor: 'constant-arrival-rate',
      // QPS = 1000 (每秒 1000 个请求)
      // 可根据实际需求调整
      rate: parseInt(__ENV.TARGET_QPS) || 1000,
      timeUnit: '1s',
      // 压测持续时间
      duration: __ENV.DURATION || '30s',
      // 预分配的虚拟用户数（建议设置为 QPS 的 10-20%）
      preAllocatedVUs: 100,
      // 最大虚拟用户数（当请求积压时自动增加）
      maxVUs: 500,
    },
  },
  // 性能阈值
  thresholds: {
    // 95% 的请求应该在 200ms 内完成
    'http_req_duration': ['p(95)<200', 'p(99)<500'],
    // 错误率应该小于 1%
    'errors': ['rate<0.01'],
    // 响应时间中位数应该小于 100ms
    'response_time': ['p(50)<100'],
    // Order 创建成功率应该大于 99%
    'order_created': ['rate>0.99'],
  },
};

export default function () {
  // 使用根路径（Fluent Bit HTTP input 接受任何路径）
  const url = 'http://localhost:8888/';
  
  // 生成测试数据
  const timestamp = new Date().toISOString();
  const randomId = Math.floor(Math.random() * 1000000);
  const orderId = `ORD-${Date.now()}-${randomId}`;
  const userId = `USER-${Math.floor(Math.random() * 10000)}`;
  const amount = (Math.random() * 1000 + 10).toFixed(2);
  
  // 随机生成日志级别（90% INFO, 10% ERROR）
  const logLevel = Math.random() > 0.1 ? 'INFO' : 'ERROR';
  const message = logLevel === 'INFO' 
    ? `[ORDER] Order created successfully - Order ID: ${orderId}, User: ${userId}, Amount: $${amount}`
    : `[ORDER] Payment failed - Order ID: ${orderId}, User: ${userId}, Amount: $${amount}`;
  
  // 根据 FLUENT_BIT_HTTP_CURL_FORMAT.md 的格式构建 payload
  const payload = JSON.stringify({
    message: message,
    level: logLevel,
    order_id: orderId,
    user_id: userId,
    amount: amount,
    timestamp: timestamp,
  });
  
  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
    tags: {
      name: 'order_app_http_input',
      service: 'order-app',
    },
    timeout: '10s',
  };
  
  // 记录请求开始时间
  const startTime = Date.now();
  
  // 发送 POST 请求
  const res = http.post(url, payload, params);
  
  // 计算响应时间
  const responseTimeMs = Date.now() - startTime;
  responseTime.add(responseTimeMs);
  
  // 验证响应（根据文档，成功响应是 200 或 201）
  const success = check(res, {
    'status is 200 or 201': (r) => r.status === 200 || r.status === 201,
    'response received': (r) => r.status >= 200 && r.status < 300,
  });
  
  // 记录错误率
  errorRate.add(!success);
  
  // 记录业务指标
  if (success && logLevel === 'INFO') {
    orderCreatedRate.add(1);
  } else if (success && logLevel === 'ERROR') {
    orderErrorRate.add(1);
  }
}

// 设置阶段钩子（压测前的准备）
export function setup() {
  // 健康检查：验证 fluent-bit HTTP input 是否可用
  const healthUrl = 'http://localhost:8888/';
  const testPayload = JSON.stringify({
    message: '[ORDER] Health check message',
    level: 'INFO',
    order_id: 'ORD-HEALTH-CHECK',
    user_id: 'USER-HEALTH',
    amount: '0.00',
  });
  
  const healthRes = http.post(healthUrl, testPayload, {
    headers: {
      'Content-Type': 'application/json',
    },
    timeout: '5s',
  });
  
  if (healthRes.status !== 200 && healthRes.status !== 201) {
    console.error('Health check failed! Please ensure fluent-bit-sidecar is running.');
    console.error(`Status: ${healthRes.status}, Response: ${healthRes.body}`);
    throw new Error(`Fluent-bit HTTP input (Order App) is not available. Status: ${healthRes.status}`);
  }
  
  console.log('✅ Health check passed. Fluent-bit HTTP input (Order App) is ready.');
  console.log('🚀 Starting Order App load test...');
  
  // 检查 OpenSearch 是否可用（可选）
  try {
    const opensearchRes = http.get('http://localhost:9200/_cluster/health', {
      timeout: '5s',
    });
    if (opensearchRes.status === 200) {
      console.log('✅ OpenSearch is available.');
    }
  } catch (e) {
    console.warn('⚠️  OpenSearch health check failed (this is optional):', e.message);
  }
  
  return { 
    startTime: new Date().toISOString(),
    targetUrl: 'http://localhost:8888/',
    service: 'order-app',
  };
}

export function teardown(data) {
  // 压测后的清理工作
  console.log(`\n📊 Load test completed at ${new Date().toISOString()}`);
  console.log(`⏰ Test started at: ${data.startTime}`);
  console.log(`🎯 Target URL: ${data.targetUrl}`);
  console.log(`📦 Service: ${data.service}`);
  
  // 查询 OpenSearch 验证日志是否写入
  try {
    // 查询正常日志
    const normalLogsRes = http.get('http://localhost:9200/order-logs-*/_count?q=service_name:order-app', {
      timeout: '10s',
    });
    if (normalLogsRes.status === 200) {
      const normalCount = JSON.parse(normalLogsRes.body).count;
      console.log(`\n✅ Normal logs in OpenSearch (order-logs-*): ${normalCount.toLocaleString()}`);
    }
    
    // 查询错误日志
    const errorLogsRes = http.get('http://localhost:9200/order-error-logs-*/_count?q=service_name:order-app', {
      timeout: '10s',
    });
    if (errorLogsRes.status === 200) {
      const errorCount = JSON.parse(errorLogsRes.body).count;
      console.log(`⚠️  Error logs in OpenSearch (order-error-logs-*): ${errorCount.toLocaleString()}`);
    }
    
    // 查询最近的日志示例
    const recentLogsRes = http.get('http://localhost:9200/order-logs-*/_search?q=service_name:order-app&size=1&sort=@timestamp:desc', {
      timeout: '10s',
    });
    if (recentLogsRes.status === 200) {
      const recentLogs = JSON.parse(recentLogsRes.body);
      if (recentLogs.hits && recentLogs.hits.hits.length > 0) {
        const latestLog = recentLogs.hits.hits[0]._source;
        console.log(`\n📝 Latest log sample:`);
        console.log(`   Order ID: ${latestLog.order_id || 'N/A'}`);
        console.log(`   Level: ${latestLog.log_level || 'N/A'}`);
        console.log(`   Timestamp: ${latestLog.processed_at || 'N/A'}`);
      }
    }
  } catch (e) {
    console.warn('⚠️  Failed to query OpenSearch (this is optional):', e.message);
  }
}
