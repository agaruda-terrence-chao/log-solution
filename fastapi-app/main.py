from fastapi import FastAPI, Query, HTTPException
import logging
import sys
from datetime import datetime

# 配置日志格式，输出到 stdout
logging.basicConfig(
    level=logging.INFO,
    format='[FASTAPI-APP] %(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)

logger = logging.getLogger(__name__)
app = FastAPI(title="Benthos Log Test API")


@app.get("/test")
async def test_log(query: str = Query(..., description="Query string parameter")):
    """
    简单的测试 API：
    - 如果 query=yolo：记录正确的日志
    - 如果 query!=yolo：记录错误的日志
    """
    timestamp = datetime.utcnow().isoformat()
    
    if query == "yolo":
        # 记录正确的日志
        logger.info(
            f"SUCCESS - Query parameter is 'yolo' | "
            f"timestamp={timestamp} | "
            f"status=200 | "
            f"message=Request processed successfully"
        )
        return {
            "status": "success",
            "message": "Query parameter is 'yolo', logging success",
            "timestamp": timestamp
        }
    else:
        # 记录错误的日志
        logger.error(
            f"ERROR - Invalid query parameter '{query}' | "
            f"timestamp={timestamp} | "
            f"status=400 | "
            f"message=Query parameter must be 'yolo'"
        )
        raise HTTPException(
            status_code=400,
            detail=f"Invalid query parameter: '{query}'. Expected 'yolo'"
        )


@app.get("/health")
async def health():
    """健康检查端点"""
    return {"status": "healthy"}

