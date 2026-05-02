"""Configuración de la base de datos SQLite con SQLAlchemy."""

from pathlib import Path

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase

DB_PATH = Path(__file__).resolve().parent.parent / "aura.db"
SQLALCHEMY_DATABASE_URL = f"sqlite:///{DB_PATH}"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},  # Necesario para SQLite con FastAPI
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    """Clase base declarativa para todos los modelos."""
    pass


def get_db():
    """Generador de sesiones de BD para inyección de dependencias en FastAPI.

    Cierra la sesión automáticamente al finalizar el request.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
