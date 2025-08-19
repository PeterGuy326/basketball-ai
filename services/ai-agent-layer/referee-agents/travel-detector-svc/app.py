from fastapi import FastAPI
from pydantic import BaseModel
from shared.common.config import load_config
from shared.common.logging import setup_logging
from shared.common.kafka_client import KafkaClient
import base64


app = FastAPI(title="TravelDetector-SVC")
cfg = load_config()
logger = setup_logging("travel-detector-svc")
kafka = KafkaClient(cfg.kafka.brokers)


class TravelRequest(BaseModel):
    video_frame: str  # base64
    imu_data: list[float]  # [x, y, z]


class TravelResponse(BaseModel):
    is_travel: bool
    confidence: float


@app.post("/travel-detection", response_model=TravelResponse)
async def detect_travel(req: TravelRequest):
    # 解码视频帧（这里先占位）
    try:
        _ = base64.b64decode(req.video_frame)
    except Exception as e:
        logger.error(f"Invalid base64 frame: {e}")

    # TODO: 集成YOLOv8 + 轨迹拟合 + IMU步数计数
    # 占位：返回固定结果并通过Kafka上报检测事件
    result = {"is_travel": False, "confidence": 0.5}

    kafka.send(
        cfg.kafka.detection_topic,
        {
            "service": "travel-detector",
            "result": result,
        },
    )

    return TravelResponse(**result)