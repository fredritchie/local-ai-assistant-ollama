from __future__ import annotations

from typing import Any

from database import connection


def get_user(username: str) -> dict[str, Any] | None:
    with connection() as conn, conn.cursor() as cursor:
        cursor.execute(
            "SELECT id, username, password_hash, is_admin "
            "FROM users WHERE username = %s",
            (username,),
        )
        return cursor.fetchone()


def create_admin(username: str, password_hash: str) -> None:
    with connection() as conn, conn.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO users (username, password_hash, is_admin)
            VALUES (%s, %s, TRUE)
            ON CONFLICT (username) DO NOTHING
            """,
            (username, password_hash),
        )
        conn.commit()


def list_conversations(user_id: int) -> list[dict[str, Any]]:
    with connection() as conn, conn.cursor() as cursor:
        cursor.execute(
            """
            SELECT id::text, title, updated_at
            FROM conversations
            WHERE user_id = %s
            ORDER BY updated_at DESC
            """,
            (user_id,),
        )
        return list(cursor.fetchall())


def load_messages(conversation_id: str, user_id: int) -> list[dict[str, str]]:
    with connection() as conn, conn.cursor() as cursor:
        cursor.execute(
            """
            SELECT m.role, m.content
            FROM messages m
            JOIN conversations c ON c.id = m.conversation_id
            WHERE c.id = %s AND c.user_id = %s
            ORDER BY m.created_at, m.id
            """,
            (conversation_id, user_id),
        )
        return list(cursor.fetchall())


def save_message(
    conversation_id: str | None, user_id: int, role: str, content: str
) -> str:
    with connection() as conn, conn.cursor() as cursor:
        if conversation_id is None:
            title = " ".join(content.split())[:160] or "New conversation"
            cursor.execute(
                "INSERT INTO conversations (user_id, title) VALUES (%s, %s) "
                "RETURNING id::text",
                (user_id, title),
            )
            conversation_id = cursor.fetchone()["id"]
        cursor.execute(
            "INSERT INTO messages (conversation_id, role, content) VALUES (%s, %s, %s)",
            (conversation_id, role, content),
        )
        cursor.execute(
            "UPDATE conversations SET updated_at = NOW() WHERE id = %s",
            (conversation_id,),
        )
        conn.commit()
        return conversation_id
