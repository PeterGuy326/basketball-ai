from dataclasses import dataclass
import os


@dataclass
class KafkaConfig:
    brokers: str = os.getenv("KAFKA_BROKERS", "kafka:9092")
    video_topic: str = os.getenv("VIDEO_TOPIC", "video.frames")
    imu_topic: str = os.getenv("IMU_TOPIC", "imu.data")
    detection_topic: str = os.getenv("DETECTION_TOPIC", "detection.events")
    rule_topic: str = os.getenv("RULE_TOPIC", "rule.events")
    foul_topic: str = os.getenv("FOUL_TOPIC", "foul.events")
    decision_topic: str = os.getenv("DECISION_TOPIC", "decision.events")


@dataclass
class DBConfig:
    url: str = os.getenv(
        "DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/basketball_ai"
    )


@dataclass
class ServiceConfig:
    host: str = os.getenv("HOST", "0.0.0.0")
    port: int = int(os.getenv("PORT", "8000"))
    log_level: str = os.getenv("LOG_LEVEL", "INFO")


@dataclass
class VisionSensorConfig:
    # 视频输入模式: local_camera, rtsp, http_receiver, dummy（实际服务强制 http_receiver）
    input_mode: str = os.getenv("VISION_INPUT_MODE", "http_receiver")
    # 本地摄像头设备号（已不使用，仅保留兼容）
    camera_device: int = int(os.getenv("CAMERA_DEVICE", "0"))
    # RTSP 流地址（已不使用，仅保留兼容）
    rtsp_url: str = os.getenv("RTSP_URL", "")
    # HTTP 推流接收端口
    http_port: int = int(os.getenv("VISION_HTTP_PORT", "8005"))
    # 帧率控制（已不使用，仅保留兼容）
    target_fps: int = int(os.getenv("TARGET_FPS", "30"))
    # 视频编码质量 (0-100)（已不使用，仅保留兼容）
    jpeg_quality: int = int(os.getenv("JPEG_QUALITY", "80"))
    # HTTP /ingest 鉴权 token（为空则不校验）
    ingest_auth_token: str = os.getenv("INGEST_AUTH_TOKEN", "")
    # 基本限流（请求/秒）
    ingest_rps_limit: int = int(os.getenv("INGEST_RPS_LIMIT", "20"))


@dataclass
class AppConfig:
    kafka: KafkaConfig = KafkaConfig()
    db: DBConfig = DBConfig()
    service: ServiceConfig = ServiceConfig()
    vision: VisionSensorConfig = VisionSensorConfig()


def load_config() -> AppConfig:
    return AppConfig()