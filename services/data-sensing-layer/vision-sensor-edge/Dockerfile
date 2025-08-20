FROM python:3.9-slim

# 使用精简版基础镜像，仅安装必要运行时
WORKDIR /workspace

COPY . /workspace

# 安装最小依赖：Kafka 客户端与日志库
RUN pip install --no-cache-dir \
    kafka-python==2.0.2 \
    structlog==23.3.0

WORKDIR /workspace/services/data-sensing-layer/vision-sensor-edge

CMD ["python", "main.py"]