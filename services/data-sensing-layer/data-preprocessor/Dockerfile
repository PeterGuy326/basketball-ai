FROM python:3.9-slim

WORKDIR /app

RUN apt-get update && apt-get install -y build-essential && rm -rf /var/lib/apt/lists/*

COPY . /workspace
WORKDIR /workspace

RUN pip install --no-cache-dir kafka-python==2.0.2 structlog==23.3.0

WORKDIR /workspace/services/data-sensing-layer/data-preprocessor

CMD ["python", "main.py"]