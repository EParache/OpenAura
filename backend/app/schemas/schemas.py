"""Schemas Pydantic para validación y serialización de la API."""

from pydantic import BaseModel, ConfigDict
from datetime import datetime
from typing import Optional, List, Dict


class MediaBase(BaseModel):
    """Campos base de un archivo multimedia."""
    title: Optional[str] = None
    path: str
    thumbnail_path: Optional[str] = None
    type: str  # 'image' | 'video'
    metadata_json: Optional[Dict] = None


class MediaCreate(MediaBase):
    """Schema para crear un nuevo archivo multimedia (herencia de MediaBase)."""
    pass


class MediaUpdate(BaseModel):
    """Schema para actualizar campos editables de un archivo multimedia."""
    title: Optional[str] = None
    filename: Optional[str] = None
    created_at: Optional[datetime] = None


class Media(MediaBase):
    """Schema de respuesta: incluye id, fecha de creación y título."""
    id: int
    title: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class AlbumBase(BaseModel):
    """Campos base de un álbum."""
    name: str


class AlbumCreate(AlbumBase):
    """Schema para crear un nuevo álbum."""
    pass


class Album(AlbumBase):
    """Schema de respuesta: incluye id, fecha y media asociada."""
    id: int
    created_at: datetime
    media: List[Media] = []

    model_config = ConfigDict(from_attributes=True)
