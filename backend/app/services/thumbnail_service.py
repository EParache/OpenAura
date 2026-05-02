"""Servicio de generación de miniaturas para imágenes y videos."""

import shutil
import subprocess
from pathlib import Path
from PIL import Image
from pillow_heif import register_heif_opener
import hashlib

register_heif_opener()

_FFMPEG_AVAILABLE = None


def _check_ffmpeg():
    global _FFMPEG_AVAILABLE
    if _FFMPEG_AVAILABLE is None:
        _FFMPEG_AVAILABLE = shutil.which("ffmpeg") is not None
        if not _FFMPEG_AVAILABLE:
            import warnings
            warnings.warn("ffmpeg not found in PATH. Video thumbnail generation will be disabled.")


CACHE_DIR = Path(__file__).resolve().parent.parent.parent / "cache" / "thumbnails"
THUMBNAIL_SIZE = (400, 400)

# Asegurar que el directorio de caché existe
CACHE_DIR.mkdir(parents=True, exist_ok=True)

_check_ffmpeg()


def generate_thumbnail(media_path: str) -> str | None:
    """Genera una miniatura JPEG para una imagen y la guarda en caché.

    Usa un hash MD5 de la ruta original como nombre de archivo para evitar
    colisiones y permitir cacheo determinista.

    Args:
        media_path: Ruta absoluta al archivo de imagen original.

    Returns:
        Ruta URL relativa a la miniatura (e.g. /thumbnails/abc123.jpg)
        o None si ocurre un error.
    """
    path = Path(media_path)
    if not path.exists():
        return None

    file_hash = hashlib.md5(str(path).encode()).hexdigest()
    thumb_filename = f"{file_hash}.jpg"
    thumb_path = CACHE_DIR / thumb_filename

    # Si ya existe la miniatura, devolverla directamente
    if thumb_path.exists():
        return f"/thumbnails/{thumb_filename}"

    try:
        with Image.open(path) as img:
            # Convertir modos no-RGB (RGBA, P) para poder guardar como JPEG
            if img.mode in ("RGBA", "P"):
                img = img.convert("RGB")

            img.thumbnail(THUMBNAIL_SIZE, Image.Resampling.LANCZOS)
            img.save(thumb_path, "JPEG", quality=95)
            return f"/thumbnails/{thumb_filename}"
    except Exception as e:
        print(f"Error generando miniatura para {media_path}: {e}")
        return None


def generate_video_thumbnail(media_path: str) -> str | None:
    """Genera una miniatura JPEG para un video extrayendo un frame con ffmpeg.

    Args:
        media_path: Ruta absoluta al archivo de video.

    Returns:
        Ruta URL relativa a la miniatura o None si ocurre un error.
    """
    path = Path(media_path)
    if not path.exists():
        return None

    file_hash = hashlib.md5(str(path).encode()).hexdigest()
    thumb_filename = f"{file_hash}.jpg"
    thumb_path = CACHE_DIR / thumb_filename

    if thumb_path.exists():
        return f"/thumbnails/{thumb_filename}"

    try:
        result = subprocess.run(
            [
                "ffmpeg",
                "-ss", "00:00:01",
                "-i", str(path),
                "-vframes", "1",
                "-vf", f"scale={THUMBNAIL_SIZE[0]}:{THUMBNAIL_SIZE[1]}:force_original_aspect_ratio=decrease,pad={THUMBNAIL_SIZE[0]}:{THUMBNAIL_SIZE[1]}:(ow-iw)/2:(oh-ih)/2",
                "-q:v", "3",
                "-y",
                str(thumb_path),
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=30,
        )
        if result.returncode == 0 and thumb_path.exists():
            return f"/thumbnails/{thumb_filename}"
    except Exception as e:
        print(f"Error generando miniatura de video para {media_path}: {e}")
    return None
