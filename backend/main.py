"""AURA API — Acervo Unificado de Recursos Audiovisuales.

Endpoints principales:
  POST /scan        — Escanea una carpeta e indexa archivos multimedia.
  POST /rescan      — Re-escanea carpetas guardadas (limpia eliminados, busca nuevos).
  GET  /scan-paths  — Lista rutas escaneadas previamente.
  GET  /media       — Lista archivos multimedia indexados.
  GET  /media/{id}  — Obtiene un archivo multimedia por ID.
  CRUD /albums      — Gestión completa de álbumes.
"""

from fastapi import FastAPI, Depends, HTTPException, BackgroundTasks
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, Response
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session, selectinload
from pathlib import Path
from app.core.database import engine, get_db, Base
from app.models import models
from app.services import scanner, thumbnail_service
from app.schemas import schemas
from typing import List
from PIL import Image
from pillow_heif import register_heif_opener
import json
import shutil
import socket
import os
import io

register_heif_opener()

# Crear tablas en la BD al iniciar
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="AURA API",
    description="Acervo Unificado de Recursos Audiovisuales",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Persistencia de rutas escaneadas ────────────────────────────────────────

SCAN_PATHS_FILE = Path(__file__).resolve().parent / "scanned_paths.json"


def _load_scan_paths() -> List[str]:
    """Carga las rutas previamente escaneadas desde el archivo JSON."""
    if SCAN_PATHS_FILE.exists():
        return json.loads(SCAN_PATHS_FILE.read_text())
    return []


def _save_scan_path(path: str):
    """Guarda una ruta escaneada en el archivo JSON (sin duplicados)."""
    paths = set(_load_scan_paths())
    paths.add(str(Path(path).resolve()))
    SCAN_PATHS_FILE.write_text(json.dumps(sorted(paths), indent=2))


# ── Archivos estáticos ───────────────────────────────────────────────────────

THUMBS_DIR = Path(__file__).resolve().parent / "cache" / "thumbnails"
THUMBS_DIR.mkdir(parents=True, exist_ok=True)
app.mount("/thumbnails", StaticFiles(directory=str(THUMBS_DIR)), name="thumbnails")


# ── Escaneo ──────────────────────────────────────────────────────────────────

@app.post("/scan", response_model=dict)
def trigger_scan(path: str, db: Session = Depends(get_db)):
    """Escanea una carpeta e indexa archivos multimedia nuevos.

    La ruta se guarda para futuros re-escaneos automáticos.
    """
    result = scanner.scan_directory(db, path)
    if "error" not in result:
        _save_scan_path(path)
    return result


@app.post("/rescan", response_model=dict)
def trigger_rescan(db: Session = Depends(get_db)):
    """Re-escanea todas las carpetas guardadas.

    Primero limpia registros cuyos archivos ya no existen en disco,
    luego busca archivos nuevos en todas las rutas conocidas.
    """
    paths = _load_scan_paths()
    if not paths:
        return {"error": "No hay carpetas escaneadas previamente"}

    cleanup = scanner.cleanup_missing(db)

    total = {"added": 0, "skipped": 0, "errors": 0}
    for p in paths:
        result = scanner.scan_directory(db, p)
        for k in total:
            total[k] += result.get(k, 0)

    total["removed"] = cleanup["removed"]
    return total


@app.get("/scan-paths", response_model=List[str])
def list_scan_paths():
    return _load_scan_paths()


@app.post("/regenerate-thumbnails")
def regenerate_thumbnails(db: Session = Depends(get_db)):
    """Regenera todas las miniaturas desde cero."""
    all_media = db.query(models.Media).all()
    total = len(all_media)
    regenerated = 0
    errors = 0

    for media in all_media:
        try:
            file_path = Path(media.path)
            if not file_path.exists():
                continue
            if media.type == 'image':
                new_thumb = thumbnail_service.generate_thumbnail(str(file_path))
            else:
                new_thumb = thumbnail_service.generate_video_thumbnail(str(file_path))
            if new_thumb:
                media.thumbnail_path = new_thumb
                if media.type == 'image':
                    media.metadata_json = scanner.get_image_metadata(file_path)
                regenerated += 1
        except Exception:
            errors += 1

    db.commit()
    return {"total": total, "regenerated": regenerated, "errors": errors}


@app.get("/host-info")
def host_info():
    """Devuelve hostname y usuario del servidor."""
    return {
        "hostname": socket.gethostname(),
        "username": os.environ.get("USER") or os.environ.get("USERNAME") or "user",
    }


# ── Media ────────────────────────────────────────────────────────────────────

@app.get("/media", response_model=List[schemas.Media])
def list_media(
    skip: int = 0,
    limit: int = 500,
    q: str = None,
    type: str = None,
    db: Session = Depends(get_db),
):
    limit = min(limit, 5000)
    query = db.query(models.Media)
    if q:
        query = query.filter(models.Media.title.ilike(f"%{q}%"))
    if type:
        query = query.filter(models.Media.type == type)
    return query.order_by(models.Media.created_at.desc()).offset(skip).limit(limit).all()


@app.get("/media/{media_id}", response_model=schemas.Media)
def get_media(media_id: int, db: Session = Depends(get_db)):
    """Obtiene un archivo multimedia por su ID."""
    media = db.query(models.Media).filter(models.Media.id == media_id).first()
    if not media:
        raise HTTPException(status_code=404, detail="Archivo no encontrado")
    return media


@app.get("/media/{media_id}/file")
def serve_media_file(media_id: int, db: Session = Depends(get_db), bg: BackgroundTasks = None):
    """Sirve el archivo original a resolucion completa.
    Convierte HEIC a JPEG y videos a MP4 al vuelo para compatibilidad con navegadores."""
    media = db.query(models.Media).filter(models.Media.id == media_id).first()
    if not media:
        raise HTTPException(status_code=404, detail="Archivo no encontrado")
    file_path = Path(media.path)
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="Archivo no encontrado en disco")

    suffix = file_path.suffix.lower()
    if suffix in ('.heic', '.heif'):
        try:
            img = Image.open(file_path)
            if img.mode in ('RGBA', 'P'):
                img = img.convert('RGB')
            buf = io.BytesIO()
            img.save(buf, format='JPEG', quality=92)
            buf.seek(0)
            return Response(content=buf.getvalue(), media_type='image/jpeg')
        except Exception:
            return FileResponse(file_path)

    if suffix in ('.mov', '.avi', '.mkv'):
        try:
            import tempfile
            out = tempfile.NamedTemporaryFile(suffix='.mp4', delete=False)
            out.close()
            subprocess.run(
                ["ffmpeg", "-i", str(file_path), "-c:v", "libx264",
                 "-preset", "ultrafast", "-crf", "28", "-c:a", "aac",
                 "-movflags", "faststart", "-y", out.name],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                timeout=60,
            )
            with open(out.name, 'rb') as f:
                data = f.read()
            os.unlink(out.name)
            return Response(content=data, media_type='video/mp4')
        except Exception:
            return FileResponse(file_path)

    return FileResponse(file_path)


@app.put("/media/{media_id}", response_model=schemas.Media)
def update_media(
    media_id: int, data: schemas.MediaUpdate, db: Session = Depends(get_db)
):
    """Actualiza campos editables de un archivo multimedia (título, nombre, fecha)."""
    media = db.query(models.Media).filter(models.Media.id == media_id).first()
    if not media:
        raise HTTPException(status_code=404, detail="Archivo no encontrado")

    # Renombrar archivo en disco
    if data.filename is not None and data.filename.strip():
        # Sanitizar: solo el nombre base, sin path traversal
        safe_name = Path(data.filename.strip()).name
        if not safe_name or safe_name in ('.', '..'):
            raise HTTPException(status_code=400, detail="Nombre de archivo invalido")
        old_path = Path(media.path)
        new_path = old_path.parent / safe_name

        if not old_path.exists():
            raise HTTPException(status_code=404, detail="Archivo original no encontrado en disco")
        if new_path.exists() and new_path != old_path:
            raise HTTPException(
                status_code=409, detail="Ya existe un archivo con ese nombre en el directorio"
            )

        media.path = str(new_path)

        # Regenerar miniatura con nueva ruta
        if media.type == 'image':
            new_thumb = thumbnail_service.generate_thumbnail(str(new_path))
            if new_thumb:
                if media.thumbnail_path:
                    old_thumb = (
                        thumbnail_service.CACHE_DIR
                        / Path(media.thumbnail_path).name
                    )
                    old_thumb.unlink(missing_ok=True)
                media.thumbnail_path = new_thumb

        # Commit DB primero, luego renombrar en disco
        db.commit()
        try:
            shutil.move(str(old_path), str(new_path))
        except Exception as e:
            # Rollback: restaurar path original en DB
            media.path = str(old_path)
            db.commit()
            raise HTTPException(status_code=500, detail=f"No se pudo renombrar: {str(e)}")

        db.refresh(media)
        return media

    if data.title is not None:
        media.title = data.title
    if data.created_at is not None:
        media.created_at = data.created_at

    db.commit()
    db.refresh(media)
    return media


@app.delete("/media/{media_id}")
def delete_media(media_id: int, db: Session = Depends(get_db)):
    """Elimina un archivo multimedia del disco y de la base de datos."""
    media = db.query(models.Media).filter(models.Media.id == media_id).first()
    if not media:
        raise HTTPException(status_code=404, detail="Archivo no encontrado")

    # Borrar miniatura del cache
    if media.thumbnail_path:
        thumb_file = (
            thumbnail_service.CACHE_DIR / Path(media.thumbnail_path).name
        )
        thumb_file.unlink(missing_ok=True)

    # Borrar archivo del disco
    file_path = Path(media.path)
    if file_path.exists():
        try:
            file_path.unlink()
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"No se pudo eliminar el archivo: {str(e)}")

    db.delete(media)
    db.commit()
    return {"detail": "Archivo eliminado"}


# ── Álbumes ──────────────────────────────────────────────────────────────────

@app.post("/albums", response_model=schemas.Album, status_code=201)
def create_album(album: schemas.AlbumCreate, db: Session = Depends(get_db)):
    """Crea un nuevo álbum. Retorna 400 si el nombre ya existe."""
    existing = (
        db.query(models.Album).filter(models.Album.name == album.name).first()
    )
    if existing:
        raise HTTPException(status_code=409, detail="Ya existe un album con ese nombre")

    new_album = models.Album(name=album.name)
    db.add(new_album)
    db.commit()
    db.refresh(new_album)
    return new_album


@app.get("/albums", response_model=List[schemas.Album])
def list_albums(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    """Lista todos los álbumes, con paginacion."""
    return (
        db.query(models.Album)
        .options(selectinload(models.Album.media))
        .offset(skip)
        .limit(limit)
        .all()
    )


@app.get("/albums/{album_id}", response_model=schemas.Album)
def get_album(album_id: int, db: Session = Depends(get_db)):
    """Obtiene un álbum con su contenido multimedia."""
    album = (
        db.query(models.Album)
        .options(selectinload(models.Album.media))
        .filter(models.Album.id == album_id)
        .first()
    )
    if not album:
        raise HTTPException(status_code=404, detail="Álbum no encontrado")
    return album


@app.put("/albums/{album_id}", response_model=schemas.Album)
def update_album(
    album_id: int, album_data: schemas.AlbumCreate, db: Session = Depends(get_db)
):
    """Renombra un álbum. Retorna 400 si el nuevo nombre ya existe."""
    album = db.query(models.Album).filter(models.Album.id == album_id).first()
    if not album:
        raise HTTPException(status_code=404, detail="Álbum no encontrado")

    conflict = (
        db.query(models.Album)
        .filter(
            models.Album.name == album_data.name,
            models.Album.id != album_id,
        )
        .first()
    )
    if conflict:
        raise HTTPException(status_code=409, detail="Ya existe un album con ese nombre")

    album.name = album_data.name
    db.commit()
    db.refresh(album)
    return album


@app.delete("/albums/{album_id}", status_code=204)
def delete_album(album_id: int, db: Session = Depends(get_db)):
    """Elimina un álbum. No borra los archivos multimedia asociados."""
    album = db.query(models.Album).filter(models.Album.id == album_id).first()
    if not album:
        raise HTTPException(status_code=404, detail="Álbum no encontrado")
    db.delete(album)
    db.commit()
    return None


@app.post("/albums/{album_id}/media/{media_id}", response_model=schemas.Album)
def add_media_to_album(
    album_id: int, media_id: int, db: Session = Depends(get_db)
):
    """Añade un archivo multimedia a un álbum. Retorna 409 si ya existe."""
    album = db.query(models.Album).filter(models.Album.id == album_id).first()
    if not album:
        raise HTTPException(status_code=404, detail="Álbum no encontrado")

    media = db.query(models.Media).filter(models.Media.id == media_id).first()
    if not media:
        raise HTTPException(status_code=404, detail="Archivo multimedia no encontrado")

    if media in album.media:
        raise HTTPException(status_code=409, detail="El archivo ya pertenece a este álbum")

    album.media.append(media)
    db.commit()
    db.refresh(album)
    return album


@app.delete("/albums/{album_id}/media/{media_id}", response_model=schemas.Album)
def remove_media_from_album(
    album_id: int, media_id: int, db: Session = Depends(get_db)
):
    """Quita un archivo multimedia de un álbum."""
    album = db.query(models.Album).filter(models.Album.id == album_id).first()
    if not album:
        raise HTTPException(status_code=404, detail="Álbum no encontrado")

    media = db.query(models.Media).filter(models.Media.id == media_id).first()
    if not media:
        raise HTTPException(status_code=404, detail="Archivo multimedia no encontrado")

    if media not in album.media:
        raise HTTPException(status_code=404, detail="El archivo no pertenece a este álbum")

    album.media.remove(media)
    db.commit()
    db.refresh(album)
    return album


# ── Frontend Web (SPA) ───────────────────────────────────────────────────────
# Debe ir al final para que las rutas de la API tengan prioridad.
# Cualquier ruta no reconocida sirve index.html (la SPA maneja el ruteo).

WEB_DIR = Path(__file__).resolve().parent.parent / "frontend" / "build" / "web"
if WEB_DIR.exists():

    @app.get("/{full_path:path}")
    async def serve_spa(full_path: str):
        file_path = WEB_DIR / full_path
        if file_path.exists() and file_path.is_file():
            return FileResponse(file_path)
        return FileResponse(WEB_DIR / "index.html")
