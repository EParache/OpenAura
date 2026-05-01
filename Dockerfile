# Open AURA — Dockerfile multi-etapa
# Etapa 1: compilar frontend Flutter para web
FROM ghcr.io/cirruslabs/flutter:3.29.3 AS frontend-builder
WORKDIR /src
COPY frontend/pubspec.yaml frontend/pubspec.lock ./
RUN flutter pub get
COPY frontend/ ./
RUN flutter build web --release --no-tree-shake-icons

# Etapa 2: backend Python
FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libheif-dev \
    && rm -rf /var/lib/apt/lists/*

COPY backend/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

COPY backend/ /app/backend/
COPY --from=frontend-builder /src/build/web /app/frontend/build/web

RUN mkdir -p /app/backend/cache/thumbnails

WORKDIR /app/backend
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
