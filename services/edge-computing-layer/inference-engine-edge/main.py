import json
import base64
import numpy as np
import cv2
from ultralytics import YOLO
from shared.common.config import load_config
from shared.common.logging import setup_logging
from shared.common.kafka_client import KafkaClient
from kafka import KafkaConsumer
from sqlalchemy import create_engine, text
import time


class InferenceEngineEdge:
    def __init__(self):
        self.cfg = load_config()
        self.logger = setup_logging("inference-engine-edge")
        self.kafka = KafkaClient(self.cfg.kafka.brokers)
        
        # 初始化数据库连接
        self.engine = create_engine(self.cfg.db.url, future=True)
        
        # 初始化YOLOv8模型
        try:
            self.model = YOLO("yolov8s.pt")  # 轻量化模型
            self.logger.info("YOLOv8s model loaded successfully")
        except Exception as e:
            self.logger.error(f"Failed to load YOLOv8 model: {e}")
            self.model = None
        
        self.consumer = KafkaConsumer(
            "video.frames.processed",
            bootstrap_servers=self.cfg.kafka.brokers,
            value_deserializer=lambda m: json.loads(m.decode("utf-8")),
            auto_offset_reset="latest",
            enable_auto_commit=True,
            group_id="inference-engine",
        )

    def _save_detection_to_db(self, result):
        """将检测结果保存到 TimescaleDB"""
        try:
            with self.engine.connect() as conn:
                # 插入每个检测对象的记录
                for detection in result["detections"]:
                    bbox = detection["bbox"]
                    sql = text("""
                        INSERT INTO detection_events 
                        (timestamp, game_id, event_type, player_id, confidence, 
                         bbox_x1, bbox_y1, bbox_x2, bbox_y2, tracking_info, raw_data)
                        VALUES 
                        (NOW(), 1, :event_type, :player_id, :confidence, 
                         :bbox_x1, :bbox_y1, :bbox_x2, :bbox_y2, :tracking_info, :raw_data)
                    """)
                    
                    # 假设 person 类的检测对象是球员
                    player_id = f"player_{hash(str(bbox)) % 100}" if detection["class"] == "person" else None
                    
                    conn.execute(sql, {
                        "event_type": f"{detection['class']}_detected",
                        "player_id": player_id,
                        "confidence": detection["confidence"],
                        "bbox_x1": bbox[0],
                        "bbox_y1": bbox[1],
                        "bbox_x2": bbox[2],
                        "bbox_y2": bbox[3],
                        "tracking_info": json.dumps(result["tracking_info"]),
                        "raw_data": json.dumps(result)
                    })
                conn.commit()
                
        except Exception as e:
            self.logger.error(f"Failed to save detection to DB: {e}")

    def process_frame(self, frame_data):
        """
        对视频帧进行目标检测与跟踪
        """
        try:
            # 解码base64图像
            img_bytes = base64.b64decode(frame_data["frame"])
            nparr = np.frombuffer(img_bytes, np.uint8)
            frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            
            if self.model is None:
                # 模型未加载，返回虚拟检测结果
                return {
                    "timestamp": frame_data["timestamp"],
                    "detections": [
                        {
                            "class": "basketball",
                            "confidence": 0.8,
                            "bbox": [100, 100, 200, 200]
                        },
                        {
                            "class": "person",
                            "confidence": 0.9,
                            "bbox": [300, 200, 400, 500]
                        }
                    ],
                    "tracking_info": {
                        "ball_trajectory": [[150, 150], [160, 160], [170, 170]],
                        "player_positions": [[350, 350]]
                    }
                }
            
            # 执行推理
            results = self.model(frame, conf=0.3)
            
            detections = []
            for r in results:
                boxes = r.boxes
                if boxes is not None:
                    for box in boxes:
                        # 提取检测信息
                        x1, y1, x2, y2 = box.xyxy[0].tolist()
                        conf = box.conf[0].item()
                        cls = int(box.cls[0].item())
                        
                        detections.append({
                            "class": self.model.names[cls],
                            "confidence": conf,
                            "bbox": [x1, y1, x2, y2]
                        })
            
            return {
                "timestamp": frame_data["timestamp"],
                "detections": detections,
                "tracking_info": self._compute_tracking(detections)
            }
            
        except Exception as e:
            self.logger.error(f"Frame processing error: {e}")
            return None

    def _compute_tracking(self, detections):
        """
        计算目标跟踪信息
        占位实现：实际应集成DeepSORT
        """
        ball_positions = []
        player_positions = []
        
        for det in detections:
            bbox = det["bbox"]
            center_x = (bbox[0] + bbox[2]) / 2
            center_y = (bbox[1] + bbox[3]) / 2
            
            if det["class"] == "sports ball":
                ball_positions.append([center_x, center_y])
            elif det["class"] == "person":
                player_positions.append([center_x, center_y])
        
        return {
            "ball_trajectory": ball_positions,
            "player_positions": player_positions
        }

    def run(self):
        self.logger.info("Inference Engine Edge started")
        
        for message in self.consumer:
            frame_data = message.value
            
            # 处理帧
            result = self.process_frame(frame_data)
            
            if result:
                # 保存检测结果到数据库
                self._save_detection_to_db(result)
                
                # 发布检测结果到Kafka
                self.kafka.send(self.cfg.kafka.detection_topic, result)
                
                self.logger.info(f"Processed frame with {len(result['detections'])} detections")


if __name__ == "__main__":
    engine = InferenceEngineEdge()
    engine.run()