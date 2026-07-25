#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

IMAGE_NAME="local-ai-assistant"
DEFAULT_MODEL="${DEFAULT_MODEL:-llama3.2:3b}"
OLLAMA_PID=""
OLLAMA_LOG="${TMPDIR:-/tmp}/local-ai-assistant-ollama.log"
DOCKER_COMMAND=(docker)

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

install_curl() {
    if command -v curl >/dev/null 2>&1; then
        return
    fi

    if command -v apt-get >/dev/null 2>&1; then
        run_as_root apt-get update
        run_as_root apt-get install -y curl ca-certificates
    elif command -v dnf >/dev/null 2>&1; then
        run_as_root dnf install -y curl ca-certificates
    elif command -v yum >/dev/null 2>&1; then
        run_as_root yum install -y curl ca-certificates
    else
        echo "curl is required but no supported package manager was found." >&2
        exit 1
    fi
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
            install_curl
            curl -fsSL https://ollama.com/install.sh | sh
            ;;
        *)
            echo "Automatic Ollama installation is supported on Linux and macOS." >&2
            exit 1
            ;;
    esac
}

install_docker() {
    case "$(uname -s)" in
        Darwin)
            if ! command -v brew >/dev/null 2>&1; then
                echo "Homebrew is required to install Docker Desktop on macOS: https://brew.sh" >&2
                exit 1
            fi
            brew install --cask docker-desktop
            ;;
        Linux)
            if command -v apt-get >/dev/null 2>&1; then
                run_as_root apt-get update
                run_as_root apt-get install -y docker.io
            elif command -v dnf >/dev/null 2>&1; then
                run_as_root dnf install -y docker
            elif command -v yum >/dev/null 2>&1; then
                run_as_root yum install -y docker
            else
                echo "No supported Linux package manager was found." >&2
                exit 1
            fi
            ;;
        *)
            echo "Automatic Docker installation is supported on Linux and macOS." >&2
            exit 1
            ;;
    esac
}

start_docker() {
    case "$(uname -s)" in
        Darwin)
            open -a Docker
            ;;
        Linux)
            if command -v systemctl >/dev/null 2>&1; then
                run_as_root systemctl enable --now docker
            elif command -v service >/dev/null 2>&1; then
                run_as_root service docker start
            fi
            ;;
    esac
}

if ! command -v ollama >/dev/null 2>&1; then
    install_ollama
fi

if ! command -v ollama >/dev/null 2>&1; then
    echo "Ollama installation did not provide an ollama command." >&2
    exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
    install_docker
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "Docker installation did not provide a docker command." >&2
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    start_docker

    for _ in {1..60}; do
        if docker info >/dev/null 2>&1; then
            break
        fi
        sleep 2
    done
fi

if ! docker info >/dev/null 2>&1; then
    if command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
        DOCKER_COMMAND=(sudo docker)
    else
        echo "Docker was installed but its service is unavailable." >&2
        exit 1
    fi
fi

cleanup() {
    if [[ -n "$OLLAMA_PID" ]] && kill -0 "$OLLAMA_PID" >/dev/null 2>&1; then
        kill "$OLLAMA_PID"
    fi
}

trap cleanup EXIT INT TERM

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

"${DOCKER_COMMAND[@]}" build --pull -t "$IMAGE_NAME" .

if [[ "$(uname -s)" == "Linux" ]]; then
    "${DOCKER_COMMAND[@]}" run \
        --rm \
        --network host \
        -e OLLAMA_BASE_URL=http://localhost:11434 \
        "$IMAGE_NAME"
else
    "${DOCKER_COMMAND[@]}" run \
        --rm \
        -p 8501:8501 \
        --add-host host.docker.internal:host-gateway \
        -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
        "$IMAGE_NAME"
fi
