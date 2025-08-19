FROM python:3.9-slim

WORKDIR /app

RUN apt-get update && apt-get install -y build-essential && rm -rf /var/lib/apt/lists/*

COPY . /workspace
WORKDIR /workspace

# Install minimal Python dependencies for UI only
RUN pip install --no-cache-dir \
    streamlit==1.25.0 \
    plotly==5.15.0 \
    matplotlib==3.7.0 \
    seaborn==0.12.0 \
    structlog==23.1.0 \
    requests==2.31.0 \
    pandas==2.0.0

WORKDIR /workspace/services/user-interaction-layer/referee-ui

EXPOSE 8501
CMD ["streamlit", "run", "app.py", "--server.port", "8501", "--server.address", "0.0.0.0"]