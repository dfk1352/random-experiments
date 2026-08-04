#!/usr/bin/env bash
set -uo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# --- Edit these defaults for your setup ---
IMAGE="${IMAGE:-ghcr.io/ggml-org/llama.cpp:full-cuda13}"
MODEL="${MODEL:-/models/your-model.gguf}"   # MODEL: container path to your GGUF file (mounted via --models-dir)
MODELS_DIR="${MODELS_DIR:-"$ROOT_DIR/models"}"
# ------------------------------------------

START_NGL=40
MIN_NGL=0
MAX_NGL=64
CONTEXT=262144
CACHE_K=
CACHE_V=

usage() {
    cat <<'EOF'
Usage: probe-ngl.sh [OPTIONS]

Probe for the optimal -ngl (GPU layer offload) value.

Options:
  --model PATH       Container path to GGUF model (default: /models/your-model.gguf)
  --models-dir PATH  Local models directory to mount (default: ./models)
  --context N        Context size (-c, default: 262144)
  --cache-k TYPE     K cache type (-ctk), e.g. q8_0, f16
  --cache-v TYPE     V cache type (-ctv), e.g. q8_0, f16
  --start-ngl N      Initial -ngl probe value (default: 40)
  --min-ngl N        Lower search bound (default: 0)
  --max-ngl N        Upper search bound (default: 64)
  --image IMAGE      Docker image (default: ghcr.io/ggml-org/llama.cpp:full-cuda13)
  -h, --help         Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --model)      MODEL="$2";      shift 2 ;;
        --models-dir) MODELS_DIR="$2"; shift 2 ;;
        --context)    CONTEXT="$2";    shift 2 ;;
        --cache-k)    CACHE_K="$2";    shift 2 ;;
        --cache-v)    CACHE_V="$2";    shift 2 ;;
        --start-ngl)  START_NGL="$2";  shift 2 ;;
        --min-ngl)    MIN_NGL="$2";    shift 2 ;;
        --max-ngl)    MAX_NGL="$2";    shift 2 ;;
        --image)      IMAGE="$2";      shift 2 ;;
        -h|--help)    usage; exit 0 ;;
        *)            printf "Unknown option: %s\n" "$1" >&2; usage; exit 1 ;;
    esac
done

run_probe() {
    local context=$1 cache_k=$2 cache_v=$3 ngl=$4
    local extra_args=()

    [[ -n "$context" ]] && extra_args+=(-c "$context")
    [[ -n "$cache_k" ]] && extra_args+=(-ctk "$cache_k")
    [[ -n "$cache_v" ]] && extra_args+=(-ctv "$cache_v")

    docker run -it --rm --gpus all \
        -v "$MODELS_DIR:/models:ro" \
        --entrypoint /app/llama-cli \
        "$IMAGE" \
        -m "$MODEL" \
        -b 2048 -ub 512 -fa on \
        -ngl "$ngl" \
        ${extra_args[@]+"${extra_args[@]}"} \
        --no-conversation --no-display-prompt --no-show-timings \
        -p ' ' -n 0
}

probe() {
    local successful_ngl=

    printf '\n===== Probe -ngl %s =====\n\n' "$START_NGL"

    if run_probe "$CONTEXT" "$CACHE_K" "$CACHE_V" "$START_NGL"; then
        successful_ngl=$START_NGL
        for ((ngl = START_NGL + 1; ngl <= MAX_NGL; ngl++)); do
            printf '\n===== Probe -ngl %s =====\n\n' "$ngl"
            if run_probe "$CONTEXT" "$CACHE_K" "$CACHE_V" "$ngl"; then
                successful_ngl=$ngl
            else
                break
            fi
        done
    else
        printf '\n===== Initial probe failed; searching downward =====\n\n'
        for ((ngl = START_NGL - 1; ngl >= MIN_NGL; ngl--)); do
            printf '\n===== Probe -ngl %s =====\n\n' "$ngl"
            if run_probe "$CONTEXT" "$CACHE_K" "$CACHE_V" "$ngl"; then
                successful_ngl=$ngl
                break
            fi
        done
    fi

    if [[ -z "${successful_ngl:-}" ]]; then
        printf 'No fitting -ngl found in range %s..%s.\n' "$MIN_NGL" "$MAX_NGL" >&2
        return 1
    fi

    printf '\n==> Optimal -ngl: %s\n' "$successful_ngl"
}

probe
