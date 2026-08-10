from __future__ import annotations

from collections.abc import Iterator
from contextlib import contextmanager

import psycopg
from psycopg.rows import dict_row

from config import (
    DATABASE_HOST,
    DATABASE_NAME,
    DATABASE_PASSWORD,
    DATABASE_PORT,
    DATABASE_SSLMODE,
    DATABASE_USERNAME,
)


class DatabaseError(RuntimeError):
    """Raised when durable application storage is not configured or available."""


def _connection_kwargs() -> dict[str, object]:
    if not DATABASE_HOST or not DATABASE_USERNAME or not DATABASE_PASSWORD:
        raise DatabaseError(
            "Database credentials are not configured. Set the RDS secret or "
            "DATABASE_HOST, DATABASE_USERNAME, and DATABASE_PASSWORD."
        )
    return {
        "host": DATABASE_HOST,
        "port": DATABASE_PORT,
        "dbname": DATABASE_NAME,
        "user": DATABASE_USERNAME,
        "password": DATABASE_PASSWORD,
        "sslmode": DATABASE_SSLMODE,
        "row_factory": dict_row,
    }


@contextmanager
def connection() -> Iterator[psycopg.Connection[dict[str, object]]]:
    try:
        with psycopg.connect(**_connection_kwargs()) as conn:
            yield conn
    except DatabaseError:
        raise
    except psycopg.Error as exc:
        raise DatabaseError("Unable to connect to the chat database.") from exc


def initialize_database() -> None:
    """Create the durable identity and chat schema; safe on every app start."""
    with connection() as conn, conn.cursor() as cursor:
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS users (
                id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                username VARCHAR(128) UNIQUE NOT NULL,
                password_hash VARCHAR(255) NOT NULL,
                is_admin BOOLEAN NOT NULL DEFAULT FALSE,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            );
            CREATE TABLE IF NOT EXISTS conversations (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                title VARCHAR(160) NOT NULL,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            );
            CREATE INDEX IF NOT EXISTS conversations_user_updated_idx
                ON conversations (user_id, updated_at DESC);
            CREATE TABLE IF NOT EXISTS messages (
                id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                conversation_id UUID NOT NULL REFERENCES conversations(id)
                    ON DELETE CASCADE,
                role VARCHAR(16) NOT NULL CHECK (role IN ('user', 'assistant')),
                content TEXT NOT NULL,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            );
            CREATE INDEX IF NOT EXISTS messages_conversation_created_idx
                ON messages (conversation_id, created_at, id);
            """
        )
        conn.commit()
