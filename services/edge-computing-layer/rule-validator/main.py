import json
import time
from shared.common.config import load_config
from shared.common.logging import setup_logging
from shared.common.kafka_client import KafkaClient
from kafka import KafkaConsumer
from sqlalchemy import create_engine, text


class RuleValidator:
    def __init__(self):
        self.cfg = load_config()
        self.logger = setup_logging("rule-validator")
        self.kafka = KafkaClient(self.cfg.kafka.brokers)
        self.engine = create_engine(self.cfg.db.url, future=True)
        self.consumer = KafkaConsumer(
            self.cfg.kafka.detection_topic,
            bootstrap_servers=self.cfg.kafka.brokers,
            value_deserializer=lambda m: json.loads(m.decode("utf-8")),
            auto_offset_reset="latest",
            enable_auto_commit=True,
            group_id="rule-validator",
        )

    def _is_travel(self, tracking_info):
        """占位：使用简单规则判断走步
        思路：若持球者（近球person）在多个连续帧移动距离较大，但IMU步数>2/持球状态持续变化，则判定疑似走步。
        这里仅演示：如果球轨迹变化较小但人物移动较大，则可能是走步。
        """
        ball = tracking_info.get("ball_trajectory", [])
        players = tracking_info.get("player_positions", [])

        if len(ball) >= 2 and len(players) >= 1:
            bx0, by0 = ball[0]
            bx1, by1 = ball[-1]
            ball_move = (bx1 - bx0) ** 2 + (by1 - by0) ** 2

            # 粗略取第一个人的移动距离做演示
            px0, py0 = players[0]
            px1, py1 = players[-1] if len(players) > 1 else players[0]
            player_move = (px1 - px0) ** 2 + (py1 - py0) ** 2

            if ball_move < 25 and player_move > 400:  # 阈值占位
                return True
        return False

    def _save_rule_event(self, event):
        try:
            with self.engine.connect() as conn:
                sql = text(
                    """
                    INSERT INTO rule_events
                    (timestamp, game_id, rule_type, severity, player_id, decision, confidence, context_data)
                    VALUES (
                        to_timestamp(:timestamp), 1, :rule_type, :severity, :player_id, :decision, :confidence, :context_data
                    )
                    """
                )
                conn.execute(
                    sql,
                    {
                        "timestamp": event.get("timestamp", time.time()),
                        "rule_type": "travel",
                        "severity": "warning" if event["type"] == "travel_suspect" else "info",
                        "player_id": event.get("player_id"),
                        "decision": event["type"] == "travel_suspect",
                        "confidence": event.get("confidence", 0.5),
                        "context_data": json.dumps(event.get("detail", {})),
                    },
                )
                conn.commit()
        except Exception as e:
            self.logger.error(f"Failed to save rule event: {e}")

    def run(self):
        self.logger.info("Rule Validator started")
        for message in self.consumer:
            detection = message.value
            tracking = detection.get("tracking_info", {})
            event = {
                "timestamp": detection.get("timestamp", time.time()),
                "type": "travel_suspect" if self._is_travel(tracking) else "ok",
                "detail": {
                    "detections": detection.get("detections", []),
                    "tracking": tracking
                }
            }
            # 写入规则事件表
            self._save_rule_event(event)
            # 继续发送到 Kafka
            self.kafka.send(self.cfg.kafka.rule_topic, event)
            self.logger.info(f"Rule evaluated: {event['type']}")


if __name__ == "__main__":
    RuleValidator().run()