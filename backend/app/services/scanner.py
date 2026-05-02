"""Servicio de escaneo de directorios para indexar archivos multimedia."""

from pathlib import Path
from sqlalchemy.orm import Session
from ..models import models
from PIL import Image
from PIL.ExifTags import TAGS
from app.services import thumbnail_service
from pillow_heif import register_heif_opener
import datetime

register_heif_opener()

# Extensiones soportadas — la comparación se hace en minúsculas
SUPPORTED_IMAGES = {'.jpg', '.jpeg', '.png', '.webp', '.heic'}
SUPPORTED_VIDEOS = {'.mp4', '.mov', '.avi', '.mkv'}


def get_image_metadata(path: Path) -> dict:
    """Extrae metadata (dimensiones, formato, EXIF) de una imagen."""
    metadata = {}
    try:
        with Image.open(path) as img:
            metadata['width'], metadata['height'] = img.size
            metadata['format'] = img.format
            exif = img.getexif()
            if exif:
                for tag_id, value in exif.items():
                    tag = TAGS.get(tag_id, tag_id)
                    if isinstance(value, bytes):
                        value = value.decode(errors='replace')
                    metadata[f"exif_{tag}"] = str(value)
    except Exception as e:
        metadata['error'] = f"Could not extract EXIF: {str(e)}"
    return metadata


def get_exif_date(metadata: dict) -> datetime.datetime | None:
    """Extrae la fecha de captura desde los metadatos EXIF."""
    date_keys = ['exif_DateTimeOriginal', 'exif_DateTimeDigitized', 'exif_DateTime']
    for key in date_keys:
        value = metadata.get(key)
        if not value:
            continue
        for fmt in ('%Y:%m:%d %H:%M:%S', '%Y-%m-%d %H:%M:%S', '%Y:%m:%d %H:%M:%S'):
            try:
                return datetime.datetime.strptime(str(value).strip(), fmt)
            except ValueError:
                continue
    return None


def scan_directory(db: Session, directory_path: str) -> dict:
    """Escanea un directorio recursivamente e indexa archivos multimedia nuevos.

    Args:
        db: Sesión de SQLAlchemy.
        directory_path: Ruta absoluta a la carpeta a escanear.

    Returns:
        dict con contadores: {added, skipped, errors}.
    """
    root_path = Path(directory_path)
    if not root_path.exists():
        return {"error": "Path does not exist"}

    stats = {"added": 0, "skipped": 0, "errors": 0}
    all_supported = SUPPORTED_IMAGES | SUPPORTED_VIDEOS

    # Usamos rglob("*") para capturar archivos con cualquier capitalización de extensión
    for file_path in root_path.rglob("*"):
        if file_path.is_dir() or file_path.is_symlink():
            continue

        suffix = file_path.suffix.lower()
        if suffix not in all_supported:
            continue

        # Verificar si ya esta indexado
        db_media = (
            db.query(models.Media)
            .filter(models.Media.path == str(file_path))
            .first()
        )
        if db_media:
            # Actualizar fecha si hay EXIF
            if db_media.type == 'image':
                try:
                    metadata = get_image_metadata(file_path)
                    exif_date = get_exif_date(metadata)
                    if exif_date and db_media.created_at != exif_date:
                        db_media.created_at = exif_date
                        db_media.metadata_json = metadata
                except Exception:
                    pass

            # Si la miniatura no existe, regenerarla (ej. cache limpiado)
            thumb_file = (
                thumbnail_service.CACHE_DIR / Path(db_media.thumbnail_path).name
            ) if db_media.thumbnail_path else None
            needs_thumb = not thumb_file or not thumb_file.exists()
            if needs_thumb:
                try:
                    if db_media.type == 'image':
                        db_media.thumbnail_path = (
                            thumbnail_service.generate_thumbnail(str(file_path))
                        )
                        db_media.metadata_json = db_media.metadata_json or get_image_metadata(file_path)
                    else:
                        db_media.thumbnail_path = (
                            thumbnail_service.generate_video_thumbnail(str(file_path))
                        )
                    stats["added"] += 1
                except Exception:
                    stats["errors"] += 1
            else:
                stats["skipped"] += 1
            continue

        try:
            media_type = 'image' if suffix in SUPPORTED_IMAGES else 'video'
            metadata = {}
            thumb_path = None

            if media_type == 'image':
                metadata = get_image_metadata(file_path)
                thumb_path = thumbnail_service.generate_thumbnail(str(file_path))
            else:
                thumb_path = thumbnail_service.generate_video_thumbnail(str(file_path))

            # Usar fecha EXIF si esta disponible, sino la de modificacion del archivo
            try:
                file_mtime = datetime.datetime.fromtimestamp(file_path.stat().st_mtime)
            except OSError:
                file_mtime = datetime.datetime.utcnow()
            exif_date = get_exif_date(metadata)
            created_at = exif_date if exif_date else file_mtime

            new_media = models.Media(
                title=file_path.stem,
                path=str(file_path),
                thumbnail_path=thumb_path,
                type=media_type,
                metadata_json=metadata,
                created_at=created_at,
            )
            db.add(new_media)
            stats["added"] += 1
        except Exception:
            stats["errors"] += 1

    try:
        db.commit()
    except Exception as e:
        db.rollback()
        stats["errors"] += 1
        print(f"Error en commit final del scan: {e}")
    return stats


def cleanup_missing(db: Session) -> dict:
    """Elimina registros cuyos archivos ya no existen en disco.

    También borra las miniaturas huérfanas del caché.

    Returns:
        dict con contador: {removed}.
    """
    all_media = db.query(models.Media).all()
    removed = 0
    for media in all_media:
        if not Path(media.path).exists():
            # Borrar miniatura asociada del caché
            if media.thumbnail_path:
                thumb_file = (
                    Path(thumbnail_service.CACHE_DIR)
                    / Path(media.thumbnail_path).name
                )
                try:
                    thumb_file.unlink(missing_ok=True)
                except Exception:
                    pass
            # SQLAlchemy elimina automáticamente las filas en media_albums
            db.delete(media)
            removed += 1
    db.commit()
    return {"removed": removed}
