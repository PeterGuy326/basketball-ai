FROM python:3.9-slim

WORKDIR /app

# Install system deps
RUN apt-get update && apt-get install -y build-essential ffmpeg libsm6 libxext6 && rm -rf /var/lib/apt/lists/*

# Copy minimal code
COPY . /workspace
WORKDIR /workspace

# Install only required runtime dependencies
RUN pip install --no-cache-dir fastapi==0.103.0 uvicorn==0.23.2 structlog==23.3.0 pydantic==1.10.17 kafka-python==2.0.2

# Set workdir to service
WORKDIR /workspace/services/ai-agent-layer/referee-agents/travel-detector-svc

EXPOSE 8001
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8001"]