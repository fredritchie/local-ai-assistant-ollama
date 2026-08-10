from __future__ import annotations

import time

import streamlit as st

from auth import bootstrap_admin, logout, require_authentication
from chat_store import list_conversations, load_messages, save_message
from config import (
    DEFAULT_MODEL,
    DEFAULT_TEMPERATURE,
    MAX_HISTORY_MESSAGES,
)
from database import DatabaseError, initialize_database
from observability import logger
from ollama_client import OllamaClientError, list_models, stream_chat

st.set_page_config(
    page_title="Fred's AI Assistant",
    page_icon="🤖",
    layout="centered",
)

try:
    initialize_database()
    bootstrap_admin()
except DatabaseError as exc:
    st.error(str(exc))
    st.stop()

require_authentication()

st.title("Fred's AI Assistant")
st.caption("Private AI inference with Ollama and Streamlit.")


@st.cache_data(ttl=10)
def get_available_models() -> list[str]:
    return list_models()


try:
    available_models = get_available_models()
except OllamaClientError as exc:
    st.error(str(exc))
    st.stop()

if not available_models:
    st.warning("No Ollama models are installed. Run: ollama pull llama3.2:3b")
    st.stop()

default_index = (
    available_models.index(DEFAULT_MODEL) if DEFAULT_MODEL in available_models else 0
)

with st.sidebar:
    st.header("Settings")

    selected_model = st.selectbox(
        "Model",
        available_models,
        index=default_index,
    )

    temperature = st.slider(
        "Temperature",
        min_value=0.0,
        max_value=1.5,
        value=DEFAULT_TEMPERATURE,
        step=0.1,
    )

    if st.button("New chat", use_container_width=True):
        st.session_state.messages = []
        st.session_state.active_conversation_id = None
        st.rerun()

    st.divider()
    st.caption("Chat history")
    conversations = list_conversations(st.session_state.user["id"])
    for conversation in conversations:
        if st.button(
            conversation["title"],
            key=f"conversation-{conversation['id']}",
            use_container_width=True,
        ):
            st.session_state.active_conversation_id = conversation["id"]
            st.session_state.messages = load_messages(
                conversation["id"], st.session_state.user["id"]
            )
            st.rerun()

    if st.button("Sign out", use_container_width=True):
        logout()

if "messages" not in st.session_state:
    st.session_state.messages = []

if "active_conversation_id" not in st.session_state:
    st.session_state.active_conversation_id = None

for message in st.session_state.messages:
    with st.chat_message(message["role"]):
        st.markdown(message["content"])

prompt = st.chat_input("Ask something...")

if prompt:
    logger.info("Chat request started")
    user_message = {
        "role": "user",
        "content": prompt,
    }

    st.session_state.messages.append(user_message)
    st.session_state.active_conversation_id = save_message(
        st.session_state.active_conversation_id,
        st.session_state.user["id"],
        "user",
        prompt,
    )

    with st.chat_message("user"):
        st.markdown(prompt)

    with st.chat_message("assistant"):
        placeholder = st.empty()
        full_response = ""
        start_time = time.perf_counter()

        try:
            for chunk in stream_chat(
                messages=st.session_state.messages[-MAX_HISTORY_MESSAGES:],
                model=selected_model,
                temperature=temperature,
            ):
                full_response += chunk
                placeholder.markdown(full_response + "▌")

            elapsed = time.perf_counter() - start_time
            placeholder.markdown(full_response)
            logger.info("Chat request completed in %.2f seconds", elapsed)

            st.caption(f"Model: `{selected_model}` · Response time: `{elapsed:.2f}s`")

        except OllamaClientError as exc:
            logger.warning("Chat request failed: %s", exc)
            st.error(str(exc))
            full_response = "The model response failed."

    st.session_state.messages.append(
        {
            "role": "assistant",
            "content": full_response,
        }
    )
    save_message(
        st.session_state.active_conversation_id,
        st.session_state.user["id"],
        "assistant",
        full_response,
    )
