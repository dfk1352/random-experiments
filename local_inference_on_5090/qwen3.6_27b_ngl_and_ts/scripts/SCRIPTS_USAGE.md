# llama.cpp Offload Probe & Bench Scripts

Two scripts for finding optimal GPU layer offload (`-ngl`) and running benchmarks with `llama.cpp`.

## Prerequisites

- Docker with GPU access (`--gpus all`)
- `llama.cpp` Docker image (default: `ghcr.io/ggml-org/llama.cpp:full-cuda13`)
- GGUF model file in a local `models/` directory (adjustable via `--models-dir`)

## probe-ngl.sh

Find the highest `-ngl` value that fits in VRAM for a given configuration.

```bash
./probe-ngl.sh --model /models/your-model.gguf \
    --context 262144 --cache-k q8_0 --cache-v q8_0 \
    --start-ngl 40 --max-ngl 64
```

Probes upward from `--start-ngl`, falling back downward on failure. Prints the optimal value to terminal.

## bench-ngl.sh

Run `llama-bench` with a known `-ngl` value.

```bash
./bench-ngl.sh --model /models/your-model.gguf --ngl 50 \
    --pp 2048 --tg 128 --depth 2048 --output results/bench.csv
```

Outputs separate `pp` (prompt processing) and `tg` (text generation) rows in CSV format.

## Common flags

| Flag | Description | Default |
|---|---|---|
| `--model` | Container path to GGUF | `/models/your-model.gguf` |
| `--models-dir` | Local directory mounted to `/models` | `./models` |
| `--context` | Context size (`-c`) (probe only) | `262144` |
| `--image` | Docker image | `ghcr.io/ggml-org/llama.cpp:full-cuda13` |

Edit the `MODEL`, `MODELS_DIR`, and `IMAGE` variables near the top of each script to set your own defaults. Run `-h` or `--help` on either script for the full flag list.
