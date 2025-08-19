import cv2
import time
import threading
from shared.common.config import load_config
from shared.common.logging import setup_logging
from shared.common.kafka_client import KafkaClient
import base64


class VisionSensorEdge:
    def __init__(self):
        self.cfg = load_config()
        self.logger = setup_logging("vision-sensor-edge")
        self.kafka = KafkaClient(self.cfg.kafka.brokers)
        self.running = True

    def start_video_stream(self):
        """
        模拟8K摄像头视频流采集
        实际场景：使用RTSP协议连接摄像头
        """
        # 这里用测试摄像头代替，实际应该是 RTSP URL
        cap = cv2.VideoCapture(0)  # 或者 "rtsp://camera_ip:port/stream"
        
        if not cap.isOpened():
            self.logger.warning("Cannot open camera, using dummy frames")
            self._send_dummy_frames()
            return

        self.logger.info("Video stream started")
        
        while self.running:
            ret, frame = cap.read()
            if ret:
                # 编码为base64
                _, buffer = cv2.imencode('.jpg', frame)
                frame_b64 = base64.b64encode(buffer).decode('utf-8')
                
                # 发送到Kafka
                self.kafka.send(
                    self.cfg.kafka.video_topic,
                    {
                        "timestamp": time.time(),
                        "frame": frame_b64,
                        "source": "vision-sensor-edge"
                    }
                )
                
                # 控制帧率 (60fps)
                time.sleep(1/60)
            else:
                self.logger.error("Failed to capture frame")
                break
                
        cap.release()

    def _send_dummy_frames(self):
        """发送虚拟帧数据用于测试"""
        while self.running:
            dummy_frame = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg=="
            
            self.kafka.send(
                self.cfg.kafka.video_topic,
                {
                    "timestamp": time.time(),
                    "frame": dummy_frame,
                    "source": "vision-sensor-edge-dummy"
                }
            )
            
            time.sleep(1/60)  # 60fps

    def start_audio_stream(self):
        """模拟音频信号采集"""
        while self.running:
            # 占位：实际实现音频采集和处理
            audio_data = {"timestamp": time.time(), "audio_level": 0.5}
            
            self.kafka.send("audio.data", audio_data)
            time.sleep(0.1)  # 10Hz

    def run(self):
        """启动所有传感器线程"""
        video_thread = threading.Thread(target=self.start_video_stream)
        audio_thread = threading.Thread(target=self.start_audio_stream)
        
        video_thread.start()
        audio_thread.start()
        
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            self.logger.info("Shutting down...")
            self.running = False
            
        video_thread.join()
        audio_thread.join()


if __name__ == "__main__":
    sensor = VisionSensorEdge()
    sensor.run()