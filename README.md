# Open AURA

**Acervo Unificado de Recursos Audiovisuales** — gestor de biblioteca multimedia autoalojado.

Escanea directorios, indexa fotos y videos, genera miniaturas y permite organizarlos en álbumes. Soporta HEIC/HEIF, JPEG, PNG, WebP, MP4, MOV, AVI y MKV.

---

## Requisitos

- Python 3.10+
- Flutter SDK (solo para compilar el frontend)

## Instalación

### Backend

```bash
git clone https://github.com/EParache/OpenAura.git
cd OpenAura/backend

python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

uvicorn main:app --host 0.0.0.0 --port 8000
```

### Frontend (web)

```bash
cd OpenAura/frontend
flutter pub get
flutter build web --release
```

El backend sirve automáticamente los archivos compilados desde `frontend/build/web/`.

## Uso

1. Abrí `http://localhost:8000` en el navegador
2. Usá el ícono de carpeta en la barra lateral para escanear un directorio
3. Las fotos indexadas aparecen en la galería, agrupadas por mes

El frontend detecta automáticamente la IP del servidor en red local. Para acceder desde otro equipo usá `http://IP_DEL_SERVIDOR:8000`.

## Stack

| Componente | Tecnología |
|---|---|
| Backend | FastAPI + SQLAlchemy + SQLite + Pillow |
| Frontend | Flutter 3.29 (Material 3, modo oscuro, web + desktop) |
| HEIC/HEIF | pillow-heif con conversión a JPEG al vuelo |
