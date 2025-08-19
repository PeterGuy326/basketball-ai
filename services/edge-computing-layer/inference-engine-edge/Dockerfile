FROM python:3.9

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    ffmpeg \
    libsm6 \
    libxext6 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY . /workspace
WORKDIR /workspace

# Install only necessary edge dependencies directly
RUN pip install --no-cache-dir \
    ultralytics==8.0.200 \
    opencv-python==4.8.1.78 \
    numpy==1.24.4 \
    torch==2.0.1 \
    torchvision==0.15.2 \
    kafka-python==2.0.2 \
    structlog==23.3.0 \
    sqlalchemy==2.0.43 \
    psycopg2-binary==2.9.9

WORKDIR /workspace/services/edge-computing-layer/inference-engine-edge

CMD ["python", "main.py"]