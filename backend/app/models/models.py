"""Modelos de base de datos para AURA."""

from sqlalchemy import Column, Integer, String, DateTime, JSON, ForeignKey, Table
from sqlalchemy.orm import relationship
from ..core.database import Base
import datetime

# ── Tabla de asociación: relación Muchos a Muchos entre Media y Albums ──────
media_albums = Table(
    "media_albums",
    Base.metadata,
    Column(
        "media_id",
        Integer,
        ForeignKey("media.id", ondelete="CASCADE"),
        primary_key=True,
    ),
    Column(
        "album_id",
        Integer,
        ForeignKey("albums.id", ondelete="CASCADE"),
        primary_key=True,
    ),
)


class Media(Base):
    """Archivo multimedia indexado (imagen o video)."""

    __tablename__ = "media"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=True)
    path = Column(String, unique=True, index=True, nullable=False)
    thumbnail_path = Column(String, nullable=True)
    type = Column(String, nullable=False)  # 'image' | 'video'
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    metadata_json = Column(JSON, nullable=True)  # EXIF, dimensiones, etc.

    albums = relationship("Album", secondary=media_albums, back_populates="media")


class Album(Base):
    """Álbum que agrupa archivos multimedia."""

    __tablename__ = "albums"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True, nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    media = relationship("Media", secondary=media_albums, back_populates="albums")
