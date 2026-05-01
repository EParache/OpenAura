# Open AURA

**Acervo Unificado de Recursos Audiovisuales** — gestor de biblioteca multimedia autoalojado.

Escanea directorios, indexa fotos y videos, genera miniaturas y permite organizarlos en álbumes. Soporta HEIC/HEIF, JPEG, PNG, WebP, MP4, MOV, AVI y MKV.

---

## Instalación con Docker (recomendado)

```bash
git clone https://github.com/EParache/OpenAura.git
cd OpenAura

# Crear archivo .env con la ruta de tus fotos
echo "PHOTOS_DIR=/ruta/a/tus/fotos" > .env

docker compose up -d
```

Abrí `http://localhost:8000`. La carpeta de fotos se monta en `/photos` dentro del contenedor.

## Instalación manual

### Requisitos
- Python 3.10+
- Flutter SDK (para compilar el frontend)

### Backend

```bash
git clone https://github.com/EParache/OpenAura.git
cd OpenAura/backend

python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

uvicorn main:app --host 0.0.0.0 --port 8000
```

### Frontend (web + Linux nativo)

```bash
cd OpenAura/frontend
flutter pub get

# Web
flutter build web --release

# Linux nativo
flutter build linux --release
./build/linux/x64/release/bundle/aura_frontend
```

El backend sirve automáticamente los archivos compilados del frontend web.

## Uso

1. Abrí la app (web o nativa)
2. Usá el ícono de carpeta en la barra lateral para escanear un directorio
3. Las fotos indexadas aparecen en la galería, agrupadas por mes

El frontend detecta automáticamente la IP del servidor en red local.

## Stack

| Componente | Tecnología |
|---|---|
| Backend | FastAPI + SQLAlchemy + SQLite + Pillow |
| Frontend | Flutter 3.29 (Material 3, modo oscuro, web + desktop) |
| HEIC/HEIF | pillow-heif con conversión a JPEG al vuelo |
