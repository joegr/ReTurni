"""
Shared database connection and session management for tournament microservices.
Provides encrypted database connections and session management.
"""
import os
import logging
from typing import Generator
from sqlalchemy import create_engine, event
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import StaticPool
import asyncpg
import asyncio

logger = logging.getLogger(__name__)

# Database configuration
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://tournament_user:tournament_pass@localhost:5432/tournament_db")
REDIS_URL = os.getenv("REDIS_URL", "redis://:redis_pass@localhost:6379/0")

# Database settings
DB_POOL_SIZE = int(os.getenv("DB_POOL_SIZE", "10"))
DB_MAX_OVERFLOW = int(os.getenv("DB_MAX_OVERFLOW", "20"))
DB_POOL_TIMEOUT = int(os.getenv("DB_POOL_TIMEOUT", "30"))
DB_POOL_RECYCLE = int(os.getenv("DB_POOL_RECYCLE", "3600"))

# Create SQLAlchemy engine with connection pooling and security settings
engine = create_engine(
    DATABASE_URL,
    pool_size=DB_POOL_SIZE,
    max_overflow=DB_MAX_OVERFLOW,
    pool_timeout=DB_POOL_TIMEOUT,
    pool_recycle=DB_POOL_RECYCLE,
    pool_pre_ping=True,
    echo=os.getenv("SQL_DEBUG", "false").lower() == "true",
    connect_args={
        "sslmode": "prefer",
        "connect_timeout": 10,
        "server_settings": {
            "jit": "off",  # Disable JIT for consistency
        }
    }
)

# Create session factory
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
    expire_on_commit=False
)

# Create base class for all ORM models
Base = declarative_base()


class DatabaseManager:
    """Database manager for handling connections and sessions."""
    
    def __init__(self):
        self.engine = engine
        self.SessionLocal = SessionLocal
    
    def get_session(self) -> Generator[Session, None, None]:
        """Get database session with automatic cleanup."""
        session = self.SessionLocal()
        try:
            yield session
        except Exception as e:
            logger.error(f"Database session error: {e}")
            session.rollback()
            raise
        finally:
            session.close()
    
    def create_tables(self):
        """Create all database tables."""
        Base.metadata.create_all(bind=self.engine)
    
    def drop_tables(self):
        """Drop all database tables."""
        Base.metadata.drop_all(bind=self.engine)
    
    async def health_check(self) -> bool:
        """Check database connection health."""
        try:
            with self.engine.connect() as conn:
                conn.execute("SELECT 1")
            return True
        except Exception as e:
            logger.error(f"Database health check failed: {e}")
            return False


# Global database manager instance
db_manager = DatabaseManager()


def get_db() -> Generator[Session, None, None]:
    """Dependency function for FastAPI to get database session."""
    yield from db_manager.get_session()


@event.listens_for(engine, "connect")
def set_sqlite_pragma(dbapi_connection, connection_record):
    """Set database connection parameters for security and performance."""
    if hasattr(dbapi_connection, 'execute'):
        # Set connection timezone to UTC
        dbapi_connection.execute("SET timezone TO 'UTC'")
        # Set statement timeout
        dbapi_connection.execute("SET statement_timeout = '30s'")
        # Set lock timeout
        dbapi_connection.execute("SET lock_timeout = '10s'")


class TransactionManager:
    """Context manager for database transactions with automatic rollback."""
    
    def __init__(self, session: Session):
        self.session = session
        self.transaction = None
    
    def __enter__(self):
        self.transaction = self.session.begin()
        return self.session
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        if exc_type is not None:
            logger.error(f"Transaction failed: {exc_val}")
            self.transaction.rollback()
        else:
            self.transaction.commit()


def with_transaction(session: Session):
    """Create transaction context manager."""
    return TransactionManager(session)


# Database utility functions
def generate_hash(data: str) -> str:
    """Generate SHA-256 hash for data integrity."""
    import hashlib
    return hashlib.sha256(data.encode()).hexdigest()


def verify_hash(data: str, expected_hash: str) -> bool:
    """Verify data integrity using hash."""
    return generate_hash(data) == expected_hash


async def execute_raw_query(query: str, params: dict = None):
    """Execute raw SQL query asynchronously."""
    try:
        conn = await asyncpg.connect(DATABASE_URL)
        try:
            if params:
                result = await conn.fetch(query, *params.values())
            else:
                result = await conn.fetch(query)
            return result
        finally:
            await conn.close()
    except Exception as e:
        logger.error(f"Raw query execution failed: {e}")
        raise


class EncryptionHelper:
    """Helper class for field-level encryption."""
    
    @staticmethod
    def encrypt_field(data: str, key: str = None) -> str:
        """Encrypt sensitive field data."""
        # Implementation would use proper encryption library like cryptography
        # For now, using base64 encoding as placeholder
        import base64
        return base64.b64encode(data.encode()).decode()
    
    @staticmethod
    def decrypt_field(encrypted_data: str, key: str = None) -> str:
        """Decrypt sensitive field data."""
        # Implementation would use proper decryption
        # For now, using base64 decoding as placeholder
        import base64
        return base64.b64decode(encrypted_data.encode()).decode()


# Export commonly used items
__all__ = [
    "Base",
    "engine", 
    "SessionLocal",
    "get_db",
    "db_manager",
    "with_transaction",
    "generate_hash",
    "verify_hash",
    "EncryptionHelper",
    "execute_raw_query"
] 