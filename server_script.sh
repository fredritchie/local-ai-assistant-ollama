#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

run_as_root() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        echo "Administrator privileges are required to install system packages." >&2
        exit 1
    fi
}

install_python() {
    case "$(uname -s)" in
        Darwin)
            if ! command -v brew >/dev/null 2>&1; then
                echo "Homebrew is required to install Python on macOS: https://brew.sh" >&2
                exit 1
            fi
            brew install python
            export PATH="$(brew --prefix)/bin:$PATH"
            ;;
        Linux)
            if command -v apt-get >/dev/null 2>&1; then
                run_as_root apt-get update
                run_as_root apt-get install -y python3 python3-venv python3-pip curl ca-certificates
            elif command -v dnf >/dev/null 2>&1; then
                run_as_root dnf install -y python3 python3-pip curl ca-certificates
            elif command -v yum >/dev/null 2>&1; then
                run_as_root yum install -y python3 python3-pip curl ca-certificates
            else
                echo "No supported Linux package manager was found." >&2
                exit 1
            fi
            ;;
        *)
            echo "Automatic Python installation is supported on Linux and macOS." >&2
            exit 1
            ;;
    esac
}

find_python() {
    local candidate
    for candidate in python3 /opt/homebrew/bin/python3 /usr/local/bin/python3; do
        if command -v "$candidate" >/dev/null 2>&1 &&
            "$candidate" -c 'import sys; raise SystemExit(sys.version_info < (3, 11))' \
                >/dev/null 2>&1; then
            PYTHON_COMMAND="$candidate"
            return 0
        fi
    done
    return 1
}

install_ollama() {
    case "$(uname -s)" in
        Darwin)
            if ! command -v brew >/dev/null 2>&1; then
                echo "Homebrew is required to install Ollama on macOS: https://brew.sh" >&2
                exit 1
            fi
            brew install ollama
            ;;
        Linux)
            if ! command -v curl >/dev/null 2>&1; then
                if command -v apt-get >/dev/null 2>&1; then
                    run_as_root apt-get update
                    run_as_root apt-get install -y curl ca-certificates
                elif command -v dnf >/dev/null 2>&1; then
                    run_as_root dnf install -y curl ca-certificates
                elif command -v yum >/dev/null 2>&1; then
                    run_as_root yum install -y curl ca-certificates
                else
                    echo "curl is required to install Ollama." >&2
                    exit 1
                fi
            fi
            curl -fsSL https://ollama.com/install.sh | OLLAMA_VERSION="$OLLAMA_VERSION" sh
            ;;
        *)
            echo "Automatic Ollama installation is supported on Linux and macOS." >&2
            exit 1
            ;;
    esac
}

PYTHON_COMMAND=""
VENV_DIR=".venv"
DEFAULT_MODEL="${DEFAULT_MODEL:-llama3.2:3b}"
OLLAMA_VERSION="${OLLAMA_VERSION:-0.32.0}"
OLLAMA_PID=""
OLLAMA_LOG="${TMPDIR:-/tmp}/local-ai-assistant-ollama.log"

if ! find_python; then
    install_python
    if ! find_python; then
        echo "Python 3.11 or later could not be installed." >&2
        exit 1
    fi
fi

if ! command -v ollama >/dev/null 2>&1; then
    install_ollama
fi

if ! command -v ollama >/dev/null 2>&1; then
    echo "Ollama installation did not provide an ollama command." >&2
    exit 1
fi

cleanup() {
    if [[ -n "$OLLAMA_PID" ]] && kill -0 "$OLLAMA_PID" >/dev/null 2>&1; then
        kill "$OLLAMA_PID"
    fi
}

trap cleanup EXIT INT TERM

if ! "$VENV_DIR/bin/python" --version >/dev/null 2>&1; then
    "$PYTHON_COMMAND" -m venv --clear "$VENV_DIR"
fi

"$VENV_DIR/bin/python" -m pip install --upgrade pip
"$VENV_DIR/bin/python" -m pip install -r requirements.txt

if ! ollama list >/dev/null 2>&1; then
    ollama serve >"$OLLAMA_LOG" 2>&1 &
    OLLAMA_PID=$!

    for _ in {1..30}; do
        if ollama list >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done
fi

if ! ollama list >/dev/null 2>&1; then
    echo "Ollama failed to start. See $OLLAMA_LOG for details." >&2
    exit 1
fi

if ! ollama list | awk -v model="$DEFAULT_MODEL" \
    'NR > 1 && $1 == model { found = 1 } END { exit !found }'; then
    ollama pull "$DEFAULT_MODEL"
fi

"$VENV_DIR/bin/python" -m streamlit run app.py
