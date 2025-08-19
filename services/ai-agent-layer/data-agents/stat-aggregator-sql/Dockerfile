FROM python:3.9-slim

WORKDIR /app

RUN apt-get update && apt-get install -y build-essential && rm -rf /var/lib/apt/lists/*

COPY . /workspace
WORKDIR /workspace

RUN pip install --no-cache-dir fastapi==0.103.0 uvicorn==0.23.2 sqlalchemy==2.0.43 structlog==23.3.0 pydantic==1.10.17 psycopg2-binary==2.9.9

WORKDIR /workspace/services/ai-agent-layer/data-agents/stat-aggregator-sql

EXPOSE 8010
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8010"]