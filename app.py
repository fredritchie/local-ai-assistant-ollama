from __future__ import annotations

import time

import streamlit as st

from config import DEFAULT_MODEL, DEFAULT_TEMPERATURE
from ollama_client import OllamaClientError, list_models, stream_chat


st.set_page_config(
    page_title="Local AI Assistant",
    page_icon="🤖",
    layout="centered",
)

st.title("Local AI Assistant")
st.caption("Runs locally using Ollama and Streamlit.")


@st.cache_data(ttl=10)
def get_available_models() -> list[str]:
    return list_models()


try:
    available_models = get_available_models()
except OllamaClientError as exc:
    st.error(str(exc))
    st.stop()

if not available_models:
    st.warning(
        "No Ollama models are installed. Run: ollama pull llama3.2:3b"
    )
    st.stop()

default_index = (
    available_models.index(DEFAULT_MODEL)
    if DEFAULT_MODEL in available_models
    else 0
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

    if st.button("Clear chat", use_container_width=True):
        st.session_state.messages = []
        st.rerun()

if "messages" not in st.session_state:
    st.session_state.messages = []

for message in st.session_state.messages:
    with st.chat_message(message["role"]):
        st.markdown(message["content"])

prompt = st.chat_input("Ask something...")

if prompt:
    user_message = {
        "role": "user",
        "content": prompt,
    }

    st.session_state.messages.append(user_message)

    with st.chat_message("user"):
        st.markdown(prompt)

    with st.chat_message("assistant"):
        placeholder = st.empty()
        full_response = ""
        start_time = time.perf_counter()

        try:
            for chunk in stream_chat(
                messages=st.session_state.messages,
                model=selected_model,
                temperature=temperature,
            ):
                full_response += chunk
                placeholder.markdown(full_response + "▌")

            elapsed = time.perf_counter() - start_time
            placeholder.markdown(full_response)

            st.caption(
                f"Model: `{selected_model}` · "
                f"Response time: `{elapsed:.2f}s`"
            )

        except OllamaClientError as exc:
            st.error(str(exc))
            full_response = "The model response failed."

    st.session_state.messages.append(
        {
            "role": "assistant",
            "content": full_response,
        }
    )