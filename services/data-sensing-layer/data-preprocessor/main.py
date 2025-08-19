import time
import json
from shared.common.config import load_config
from shared.common.logging import setup_logging
from shared.common.kafka_client import KafkaClient
from kafka import KafkaConsumer


class DataPreprocessor:
    def __init__(self):
        self.cfg = load_config()
        self.logger = setup_logging("data-preprocessor")
        self.kafka = KafkaClient(self.cfg.kafka.brokers)
        self.video_consumer = KafkaConsumer(
            self.cfg.kafka.video_topic,
            bootstrap_servers=self.cfg.kafka.brokers,
            value_deserializer=lambda m: json.loads(m.decode("utf-8")),
            auto_offset_reset="latest",
            enable_auto_commit=True,
            group_id="data-preprocessor-video",
        )
        self.imu_consumer = KafkaConsumer(
            self.cfg.kafka.imu_topic,
            bootstrap_servers=self.cfg.kafka.brokers,
            value_deserializer=lambda m: json.loads(m.decode("utf-8")),
            auto_offset_reset="latest",
            enable_auto_commit=True,
            group_id="data-preprocessor-imu",
        )

    def run(self):
        self.logger.info("Data Preprocessor started")
        while True:
            # 简化：这里只消费视频流，示例基础增强处理
            for msg in self.video_consumer.poll(timeout_ms=1000).values():
                for record in msg:
                    data = record.value
                    # 占位：做去抖动、降噪等预处理
                    processed = {
                        "timestamp": data.get("timestamp", time.time()),
                        "frame": data["frame"],
                        "meta": {"stabilized": True, "denoised": True},
                    }
                    self.kafka.send("video.frames.processed", processed)


if __name__ == "__main__":
    DataPreprocessor().run()