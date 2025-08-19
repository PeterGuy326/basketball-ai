FROM python:3.9

WORKDIR /app

# Install system dependencies for OpenCV and video processing
RUN apt-get update && apt-get install -y \
    build-essential \
    ffmpeg \
    libsm6 \
    libxext6 \
    libglib2.0-0 \
    v4l-utils \
    && rm -rf /var/lib/apt/lists/*

COPY . /workspace
WORKDIR /workspace

# Install only necessary vision dependencies directly
RUN pip install --no-cache-dir \
    opencv-python==4.8.1.78 \
    numpy==1.24.4 \
    kafka-python==2.0.2 \
    structlog==23.3.0

WORKDIR /workspace/services/data-sensing-layer/vision-sensor-edge

CMD ["python", "main.py"]