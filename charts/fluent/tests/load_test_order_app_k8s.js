import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// 自定义指标
const errorRate = new Rate('errors');
const responseTime = new Trend('response_time');
const orderCreatedRate = new Rate('order_created');
const orderErrorRate = new Rate('order_errors');

// 环境配置
// 从环境变量读取，如果没有则使用默认值（支持 port-forward 本地测试）
// 如果使用 port-forward，设置为 localhost；如果在 K8s Pod 内运行，使用 Service DNS
const FLUENT_BIT_SERVICE = __ENV.FLUENT_BIT_SERVICE || 'localhost';
const FLUENT_BIT_ORDER_PORT = __ENV.FLUENT_BIT_ORDER_PORT || '8888';
const OPENSEARCH_SERVICE = __ENV.OPENSEARCH_SERVICE || 'localhost';
const OPENSEARCH_PORT = __ENV.OPENSEARCH_PORT || '9200';

export const options = {
  scenarios: {
    constant_request_rate: {
      executor: 'constant-arrival-rate',
      // QPS = 1000 (每秒 1000 个请求)
      // 可通过环境变量 TARGET_QPS 调整
      rate: parseInt(__ENV.TARGET_QPS) || 1000,
      timeUnit: '1s',
      // 压测持续时间，可通过环境变量 DURATION 调整
      duration: __ENV.DURATION || '3s',
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
  // Kubernetes 环境下的 Fluent Bit Service URL
  const url = `http://${FLUENT_BIT_SERVICE}:${FLUENT_BIT_ORDER_PORT}/`;
  
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
      name: 'order_app_http_input_k8s',
      service: 'order-app',
      environment: 'kubernetes',
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
  const isLocal = FLUENT_BIT_SERVICE === 'localhost' || FLUENT_BIT_SERVICE === '127.0.0.1';
  console.log(`🔍 Environment Configuration (${isLocal ? 'Local Port-Forward' : 'Kubernetes Pod'}):`);
  console.log(`   Fluent Bit Service: ${FLUENT_BIT_SERVICE}:${FLUENT_BIT_ORDER_PORT}`);
  console.log(`   OpenSearch Service: ${OPENSEARCH_SERVICE}:${OPENSEARCH_PORT}`);
  if (isLocal) {
    console.log(`   ⚠️  确保已设置 port-forward: kubectl port-forward -n fluent svc/fluent-fluent-bit 8888:8888`);
  }
  console.log('');
  
  // 健康检查：验证 fluent-bit HTTP input 是否可用
  const healthUrl = `http://${FLUENT_BIT_SERVICE}:${FLUENT_BIT_ORDER_PORT}/`;
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
    timeout: '10s',
  });
  
  if (healthRes.status !== 200 && healthRes.status !== 201) {
    console.error('❌ Health check failed!');
    if (isLocal) {
      console.error('   请确保已设置 port-forward:');
      console.error('   kubectl port-forward -n fluent svc/fluent-fluent-bit 8888:8888');
    } else {
      console.error('   请确保 fluent-bit-sidecar 在 Kubernetes 中运行');
    }
    console.error(`   Status: ${healthRes.status}, Response: ${healthRes.body}`);
    throw new Error(`Fluent-bit HTTP input (Order App) is not available. Status: ${healthRes.status}`);
  }
  
  console.log('✅ Health check passed. Fluent-bit HTTP input (Order App) is ready.');
  console.log(`🚀 Starting Order App load test (${isLocal ? 'Local Port-Forward' : 'Kubernetes Pod'})...`);
  
  // 检查 OpenSearch 是否可用（可选）
  try {
    const opensearchUrl = `http://${OPENSEARCH_SERVICE}:${OPENSEARCH_PORT}/_cluster/health`;
    const opensearchRes = http.get(opensearchUrl, {
      timeout: '10s',
    });
    if (opensearchRes.status === 200) {
      const health = JSON.parse(opensearchRes.body);
      console.log(`✅ OpenSearch is available. Status: ${health.status}`);
    }
  } catch (e) {
    console.warn('⚠️  OpenSearch health check failed (this is optional):', e.message);
  }
  
  return { 
    startTime: new Date().toISOString(),
    targetUrl: healthUrl,
    service: 'order-app',
    environment: 'kubernetes',
    fluentBitService: FLUENT_BIT_SERVICE,
    opensearchService: OPENSEARCH_SERVICE,
  };
}

export function teardown(data) {
  // 压测后的清理工作
  console.log(`\n📊 Load test completed at ${new Date().toISOString()}`);
  console.log(`⏰ Test started at: ${data.startTime}`);
  console.log(`🎯 Target URL: ${data.targetUrl}`);
  console.log(`📦 Service: ${data.service}`);
  console.log(`🌐 Environment: ${data.environment}`);
  console.log(`🔗 Fluent Bit Service: ${data.fluentBitService}`);
  console.log(`🔗 OpenSearch Service: ${data.opensearchService}`);
  
  // 查询 OpenSearch 验证日志是否写入
  try {
    const opensearchBaseUrl = `http://${data.opensearchService}:${OPENSEARCH_PORT}`;
    
    // 查询正常日志
    const normalLogsUrl = `${opensearchBaseUrl}/order-logs-*/_count?q=service_name:order-app`;
    const normalLogsRes = http.get(normalLogsUrl, {
      timeout: '10s',
    });
    if (normalLogsRes.status === 200) {
      const normalCount = JSON.parse(normalLogsRes.body).count;
      console.log(`\n✅ Normal logs in OpenSearch (order-logs-*): ${normalCount.toLocaleString()}`);
    }
    
    // 查询错误日志
    const errorLogsUrl = `${opensearchBaseUrl}/order-error-logs-*/_count?q=service_name:order-app`;
    const errorLogsRes = http.get(errorLogsUrl, {
      timeout: '10s',
    });
    if (errorLogsRes.status === 200) {
      const errorCount = JSON.parse(errorLogsRes.body).count;
      console.log(`⚠️  Error logs in OpenSearch (order-error-logs-*): ${errorCount.toLocaleString()}`);
    }
    
    // 查询最近的日志示例
    const recentLogsUrl = `${opensearchBaseUrl}/order-logs-*/_search?q=service_name:order-app&size=1&sort=@timestamp:desc`;
    const recentLogsRes = http.get(recentLogsUrl, {
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
        console.log(`   Hostname: ${latestLog.hostname || 'N/A'}`);
      }
    }
  } catch (e) {
    console.warn('⚠️  Failed to query OpenSearch (this is optional):', e.message);
  }
}
