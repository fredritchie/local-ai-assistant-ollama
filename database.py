from __future__ import annotations

import os
from collections.abc import Iterator
from contextlib import contextmanager

import boto3
import psycopg
from psycopg.rows import dict_row

from config import (
    DATABASE_HOST,
    DATABASE_IAM_AUTH,
    DATABASE_NAME,
    DATABASE_PASSWORD,
    DATABASE_PORT,
    DATABASE_SSLMODE,
    DATABASE_USERNAME,
)


class DatabaseError(RuntimeError):
    """Raised when durable application storage is not configured or available."""


def _connection_kwargs() -> dict[str, object]:
    if not DATABASE_HOST or not DATABASE_USERNAME:
        raise DatabaseError(
            "Database connection settings are not configured. Set DATABASE_HOST "
            "and DATABASE_USERNAME."
        )

    password = DATABASE_PASSWORD
    if DATABASE_IAM_AUTH:
        region = os.getenv("AWS_REGION") or boto3.session.Session().region_name
        if not region:
            raise DatabaseError(
                "AWS_REGION is required for IAM database authentication."
            )
        password = boto3.client("rds", region_name=region).generate_db_auth_token(
            DBHostname=DATABASE_HOST,
            Port=DATABASE_PORT,
            DBUsername=DATABASE_USERNAME,
            Region=region,
        )
    elif not password:
        raise DatabaseError(
            "Database credentials are not configured. Set DATABASE_PASSWORD or "
            "enable IAM database authentication."
        )

    return {
        "host": DATABASE_HOST,
        "port": DATABASE_PORT,
        "dbname": DATABASE_NAME,
        "user": DATABASE_USERNAME,
        "password": password,
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
