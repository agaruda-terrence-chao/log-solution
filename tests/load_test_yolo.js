import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// 自定义指标
const errorRate = new Rate('errors');
const responseTime = new Trend('response_time');

export const options = {
  scenarios: {
    constant_request_rate: {
      executor: 'constant-arrival-rate',
      // QPS = 3000 (每秒 3000 个请求)
      rate: 3000,
      timeUnit: '1s',
      // 压测持续时间（可根据需要调整）
      duration: '1m',
      // 预分配的虚拟用户数（建议设置为 QPS 的 10-20%）
      preAllocatedVUs: 200,
      // 最大虚拟用户数（当请求积压时自动增加）
      maxVUs: 1000,
    },
  },
  // 性能阈值（可选）
  thresholds: {
    // 95% 的请求应该在 500ms 内完成
    'http_req_duration': ['p(95)<500', 'p(99)<1000'],
    // 错误率应该小于 1%
    'errors': ['rate<0.01'],
    // 响应时间中位数应该小于 200ms
    'response_time': ['p(50)<200'],
  },
};

export default function () {
  const url = 'http://localhost:8000/test?query=yolo';
  
  // 记录请求开始时间
  const startTime = Date.now();
  
  // 发送 GET 请求
  const res = http.get(url, {
    tags: {
      name: 'test_yolo_endpoint',
    },
  });
  
  // 计算响应时间
  const responseTimeMs = Date.now() - startTime;
  responseTime.add(responseTimeMs);
  
  // 验证响应
  const success = check(res, {
    'status is 200': (r) => r.status === 200,
    'response has status field': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.status === 'success';
      } catch (e) {
        return false;
      }
    },
    'response has message': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.message && body.message.includes('yolo');
      } catch (e) {
        return false;
      }
    },
  });
  
  // 记录错误率
  errorRate.add(!success);
  
  // k6 会自动处理请求间隔（根据 rate 配置）
  // 这里不需要 sleep，但如果需要可以添加
  // sleep(0.001); // 1ms
}

// 设置阶段钩子（可选）
export function setup() {
  // 压测前的准备（如健康检查）
  const healthUrl = 'http://localhost:8000/health';
  const healthRes = http.get(healthUrl);
  
  if (healthRes.status !== 200) {
    console.error('Health check failed! Please ensure the FastAPI service is running.');
    throw new Error('Service is not healthy');
  }
  
  console.log('Health check passed. Starting load test...');
  return { startTime: new Date().toISOString() };
}

export function teardown(data) {
  // 压测后的清理工作（可选）
  console.log(`Load test completed at ${new Date().toISOString()}`);
  console.log(`Test started at: ${data.startTime}`);
}

