from __future__ import annotations

import bcrypt
import streamlit as st

from chat_store import create_admin, get_user
from config import ADMIN_PASSWORD_HASH, ADMIN_USERNAME, AUTH_ENABLED


def verify_credentials(username: str, password: str) -> bool:
    """Return True when the supplied credentials match a persisted user."""
    user = get_user(username)
    if not user:
        return False
    return bcrypt.checkpw(
        password.encode("utf-8"),
        str(user["password_hash"]).encode("utf-8"),
    )


def bootstrap_admin() -> None:
    """Create the configured administrator once without overwriting it later."""
    create_admin(ADMIN_USERNAME, ADMIN_PASSWORD_HASH)


def require_authentication() -> None:
    """Block the app until the user signs in."""
    if not AUTH_ENABLED:
        st.session_state.authenticated = True
        st.session_state.username = ADMIN_USERNAME
        st.session_state.user = get_user(ADMIN_USERNAME)
        return
    if st.session_state.get("authenticated"):
        return
    _render_login_form()


def logout() -> None:
    """Clear the session and return to the login screen."""
    st.session_state.pop("authenticated", None)
    st.session_state.pop("username", None)
    st.session_state.pop("messages", None)
    st.rerun()


def _render_login_form() -> None:
    st.title("Sign in")
    st.caption("Private AI inference with Ollama and Streamlit.")

    with st.form("login"):
        username = st.text_input("Username")
        password = st.text_input("Password", type="password")
        submitted = st.form_submit_button("Sign in", use_container_width=True)

    if submitted:
        if verify_credentials(username, password):
            st.session_state.authenticated = True
            st.session_state.username = username
            st.session_state.user = get_user(username)
            st.rerun()
        st.error("Invalid username or password.")

    st.stop()
