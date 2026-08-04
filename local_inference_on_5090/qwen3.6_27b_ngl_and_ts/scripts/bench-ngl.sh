#!/usr/bin/env bash
set -uo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# --- Edit these defaults for your setup ---
IMAGE="${IMAGE:-ghcr.io/ggml-org/llama.cpp:full-cuda13}"
MODEL="${MODEL:-/models/your-model.gguf}"   # container path to your GGUF file (mounted via --models-dir)
MODELS_DIR="${MODELS_DIR:-"$ROOT_DIR/models"}"
# ------------------------------------------

NGL=
PP=2048
TG=128
DEPTH=2048
REPEAT=5
OUTPUT=

usage() {
    cat <<'EOF'
Usage: bench-ngl.sh [OPTIONS]

Run llama-bench for a given -ngl configuration.

Options:
  --model PATH       Container path to GGUF model (default: /models/your-model.gguf)
  --models-dir PATH  Local models directory to mount (default: ./models)
  --ngl N            GPU layer offload value (required)
  --pp N             Prompt processing tokens (default: 2048)
  --tg N             Text generation tokens (default: 128)
  --depth N          Prefill depth (-d) (default: 2048)
  --repeat N         Number of repetitions (default: 5)
  --output PATH      Output CSV file path (default: ./bench-results.csv)
  --image IMAGE      Docker image (default: ghcr.io/ggml-org/llama.cpp:full-cuda13)
  -h, --help         Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --model)      MODEL="$2";      shift 2 ;;
        --models-dir) MODELS_DIR="$2"; shift 2 ;;
        --ngl)        NGL="$2";        shift 2 ;;
        --pp)         PP="$2";         shift 2 ;;
        --tg)         TG="$2";         shift 2 ;;
        --depth)      DEPTH="$2";      shift 2 ;;
        --repeat)     REPEAT="$2";     shift 2 ;;
        --output)     OUTPUT="$2";     shift 2 ;;
        --image)      IMAGE="$2";      shift 2 ;;
        -h|--help)    usage; exit 0 ;;
        *)            printf "Unknown option: %s\n" "$1" >&2; usage; exit 1 ;;
    esac
done

if [[ -z "$NGL" ]]; then
    printf '--ngl is required.\n' >&2
    exit 1
fi

: "${OUTPUT:="$ROOT_DIR/bench-results.csv"}"

printf 'Running benchmark with -ngl %s (pp=%s, tg=%s, depth=%s)...\n' \
    "$NGL" "$PP" "$TG" "$DEPTH" >&2

mkdir -p "$(dirname -- "$OUTPUT")"

docker run --rm --gpus all \
    -v "$MODELS_DIR:/models:ro" \
    --entrypoint /app/llama-bench \
    "$IMAGE" \
    -m "$MODEL" \
    -p "$PP" -n "$TG" -d "$DEPTH" \
    -r "$REPEAT" \
    -b 2048 -ub 512 -fa on \
    -ngl "$NGL" \
    -o csv \
    >"$OUTPUT"

printf 'Benchmark results written to: %s\n' "$OUTPUT" >&2
