from kafka import KafkaProducer, KafkaConsumer
from typing import Optional
import json


class KafkaClient:
    def __init__(self, brokers: str):
        self.producer = KafkaProducer(
            bootstrap_servers=brokers,
            value_serializer=lambda v: json.dumps(v).encode("utf-8"),
        )

    def send(self, topic: str, value: dict, key: Optional[str] = None):
        self.producer.send(topic, key=key.encode("utf-8") if key else None, value=value)
        self.producer.flush()

    @staticmethod
    def consumer(brokers: str, topic: str, group_id: str):
        return KafkaConsumer(
            topic,
            bootstrap_servers=brokers,
            group_id=group_id,
            value_deserializer=lambda m: json.loads(m.decode("utf-8")),
            auto_offset_reset="latest",
            enable_auto_commit=True,
        )