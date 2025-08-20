"""
Vision Sensor Edge 服务（默认仅 HTTP 推流接收）

数据流流程（iOS -> Kafka）:
1) iOS 端使用 AVCaptureSession 获取视频帧，编码为 JPEG 后 Base64。
2) iOS 通过 HTTP POST /ingest 将 JSON 发送到本服务：{"frame": base64_jpeg, "timestamp": epoch_seconds}。
3) 服务侧对请求进行鉴权（X-Auth-Token 或 HMAC 签名）与基本限流（RPS）。
4) 通过 KafkaClient 将消息写入 Kafka 的视频主题，供下游预处理/推理消费。

说明：
- 默认仅启用 HTTP /ingest 外部推流方式（http_receiver）。
- RTSP 配置项保留作为可选扩展（当前镜像未包含解码依赖，默认不启用）。
- 历史配置项（target_fps、jpeg_quality、camera_device、rtsp_url）仅为兼容保留，逻辑上不会触发本地设备依赖。
"""

import time
import threading
import base64
import hmac
import hashlib
from typing import Optional

from shared.common.config import load_config
from shared.common.logging import setup_logging
from shared.common.kafka_client import KafkaClient

# 轻量级 HTTP 接收（避免引入新框架），使用内置 http.server
from http.server import BaseHTTPRequestHandler, HTTPServer
import json


class VisionSensorEdge:
    def __init__(self):
        self.cfg = load_config()
        self.logger = setup_logging("vision-sensor-edge")
        self.kafka = KafkaClient(self.cfg.kafka.brokers)
        self.running = True
        # 最近一次接收到的帧（可用于监控）
        self._last_frame_b64: Optional[str] = None
        # 简单 RPS 限流计数
        self._rl_second: int = 0
        self._rl_count: int = 0

    def _send_frame(self, frame_b64: str, source: str = "vision-http-ingest"):
        """将 Base64 编码的 JPEG 帧转发到 Kafka。"""
        self.kafka.send(
            self.cfg.kafka.video_topic,
            {
                "timestamp": time.time(),
                "frame": frame_b64,
                "source": source,
            },
        )

    def start_video_stream(self):
        """
        仅启动 HTTP /ingest 接收端。
        提示：即使配置中存在其它输入模式，这里也会忽略并强制 http_receiver。
        """
        configured = self.cfg.vision.input_mode
        self.logger.info(
            f"VisionSensorEdge running in http_receiver mode only (configured={configured})"
        )
        self._run_http_receiver()

    # HTTP 推流接收：POST /ingest { frame: base64, timestamp?: number }
    def _run_http_receiver(self):
        port = int(self.cfg.vision.http_port)
        logger = self.logger
        parent = self

        class IngestHandler(BaseHTTPRequestHandler):
            def do_POST(self):
                # 仅支持 /ingest
                if self.path != "/ingest":
                    self.send_response(404)
                    self.end_headers()
                    return

                length = int(self.headers.get("Content-Length", 0))
                if length <= 0:
                    self.send_response(400)
                    self.end_headers()
                    self.wfile.write(b"missing body")
                    return

                # 鉴权：支持两种方式（任一通过即可）
                # 1) 固定 Token：请求头 X-Auth-Token == INGEST_AUTH_TOKEN
                # 2) HMAC 签名：请求头 X-Timestamp, X-Signature 存在，
                #    其中 X-Signature == hex(hmac_sha256(INGEST_AUTH_TOKEN, f"{timestamp}\n{body}"))
                secret = parent.cfg.vision.ingest_auth_token or ""
                try:
                    body_bytes = self.rfile.read(length)
                    # 如果配置了 secret，则要求鉴权通过
                    if secret:
                        token = self.headers.get("X-Auth-Token", "")
                        if token and hmac.compare_digest(token, secret):
                            pass  # token 鉴权通过
                        else:
                            ts = self.headers.get("X-Timestamp")
                            sig = self.headers.get("X-Signature")
                            if not (ts and sig):
                                self.send_response(401)
                                self.end_headers()
                                self.wfile.write(b"unauthorized")
                                return
                            # 可选：限制时间窗口 5 分钟，避免重放
                            try:
                                ts_f = float(ts)
                            except Exception:
                                self.send_response(400)
                                self.end_headers()
                                self.wfile.write(b"bad timestamp")
                                return
                            if abs(time.time() - ts_f) > 300:
                                self.send_response(401)
                                self.end_headers()
                                self.wfile.write(b"expired")
                                return
                            expected = hmac.new(
                                key=secret.encode("utf-8"),
                                msg=(f"{ts}\n".encode("utf-8") + body_bytes),
                                digestmod=hashlib.sha256,
                            ).hexdigest()
                            if not hmac.compare_digest(expected, sig):
                                self.send_response(401)
                                self.end_headers()
                                self.wfile.write(b"unauthorized")
                                return

                    # 基本限流（每秒请求数）
                    limit = int(parent.cfg.vision.ingest_rps_limit)
                    now_s = int(time.time())
                    if parent._rl_second == now_s:
                        if parent._rl_count >= max(1, limit):
                            self.send_response(429)
                            self.end_headers()
                            self.wfile.write(b"rate limited")
                            return
                        parent._rl_count += 1
                    else:
                        parent._rl_second = now_s
                        parent._rl_count = 1

                    # 解析 JSON
                    try:
                        data = json.loads(body_bytes.decode("utf-8"))
                    except Exception:
                        self.send_response(400)
                        self.end_headers()
                        self.wfile.write(b"invalid json")
                        return

                    frame_b64 = data.get("frame")
                    ts_val = float(data.get("timestamp", time.time()))
                    if not frame_b64:
                        self.send_response(400)
                        self.end_headers()
                        self.wfile.write(b"missing frame")
                        return

                    # 可选：快速校验 Base64（失败直接 400）。
                    try:
                        # 仅校验格式，不保留解码结果，避免额外内存。
                        base64.b64decode(frame_b64, validate=True)
                    except Exception:
                        self.send_response(400)
                        self.end_headers()
                        self.wfile.write(b"invalid base64")
                        return

                    parent._last_frame_b64 = frame_b64
                    parent.kafka.send(
                        parent.cfg.kafka.video_topic,
                        {"timestamp": ts_val, "frame": frame_b64, "source": "vision-http-ingest"},
                    )
                    self.send_response(200)
                    self.end_headers()
                    self.wfile.write(b"ok")
                except Exception as e:
                    logger.error(f"HTTP ingest error: {e}")
                    self.send_response(500)
                    self.end_headers()
                    self.wfile.write(b"error")

            # 降低日志噪音
            def log_message(self, format, *args):
                return

        server = HTTPServer((self.cfg.service.host, port), IngestHandler)
        logger.info(
            f"HTTP receiver started on {self.cfg.service.host}:{port} POST /ingest (auth={'on' if self.cfg.vision.ingest_auth_token else 'off'}, rps_limit={self.cfg.vision.ingest_rps_limit})"
        )
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            logger.info("HTTP receiver shutting down...")
        finally:
            server.server_close()

    def start_audio_stream(self):
        """模拟音频信号采集（与视频互不干扰，可按需保留/移除）。"""
        interval = 0.1
        while self.running:
            audio_data = {"timestamp": time.time(), "audio_level": 0.5}
            self.kafka.send("audio.data", audio_data)
            time.sleep(interval)

    def run(self):
        """启动线程：HTTP 视频接收 + 模拟音频（可选）。"""
        video_thread = threading.Thread(target=self.start_video_stream, daemon=True)
        audio_thread = threading.Thread(target=self.start_audio_stream, daemon=True)

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