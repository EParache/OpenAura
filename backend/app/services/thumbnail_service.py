"""Servicio de generación de miniaturas para imágenes."""

from pathlib import Path
from PIL import Image
from pillow_heif import register_heif_opener
import hashlib

register_heif_opener()

CACHE_DIR = Path("/home/zimba/aura/backend/cache/thumbnails")
THUMBNAIL_SIZE = (400, 400)

# Asegurar que el directorio de caché existe
CACHE_DIR.mkdir(parents=True, exist_ok=True)


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
