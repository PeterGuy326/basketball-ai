from dataclasses import dataclass
import os


@dataclass
class KafkaConfig:
    brokers: str = os.getenv("KAFKA_BROKERS", "localhost:9092")
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
class AppConfig:
    kafka: KafkaConfig = KafkaConfig()
    db: DBConfig = DBConfig()
    service: ServiceConfig = ServiceConfig()


def load_config() -> AppConfig:
    return AppConfig()