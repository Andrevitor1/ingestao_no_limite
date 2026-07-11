FROM python:3.11-slim

WORKDIR /app

RUN pip install --no-cache-dir polars pyarrow deltalake

COPY src/ ./src/

CMD ["python", "src/main.py"]
