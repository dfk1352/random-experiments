# Finding the maximum `-ngl` required to run qwen3.6 27B on q8, and the speed test result (2026/07/30)

Motivation
---

I was originally trying to run terminal bench with some harnesses to see how well they can perform with a qwen3.6 27B running locally on my 5090 (which I will definitely do later, likely also documenting here). Then I figured that it would only do justice to the model and the harnesses if I at least test with q8, despite q6 is the one I use daily. Thus I went off rail to find out the optimal setup to run q8 on 32GB vRAM.

Objective
---

To run ternimal bench reliably, I suspect need to get the context window as large as possible to avoid failure due to insufficient context, while maintaining a reasonable token generation speed so the task won't run forever.
There are two numbers to figure out here: the exact layer offload (to cpu, lower is better) needed, and the token per second with the offload set.

Experiment Setup
---

*Environment:*
- OS: Ubuntu 24.04.4 LTS
- Tools used: `llama-cli` and `llama-bench` run on the `ghcr.io/ggml-org/llama.cpp:full-cuda13` docker image
- Model: [Qwen3.6-27B-Q8_0.gguf](https://huggingface.co/unsloth/Qwen3.6-27B-GGUF) from unsloth. I presumed that they have the best quant in general, though for q8 there might be better options. As reference, `Qwen3.6-27B-UD-Q6_K_XL.gguf` comfortably fits inside 32GB vRAM with full 262144 context.

*Steps to reproduce:*
1. Pull the models and the images.
2. Run the two benchmark scripts: [1](./scripts/bench-ngl.sh) [2](./scripts/probe-ngl.sh). Set paths and parameters based on your goals. See the [description](./scripts/SCRIPTS_USAGE.md) for more info.

The probing script requires human input (ctrl+c) after each test, mainly for the sake of watching over the run in case it doesn't work out the way I wanted it to be.

Results
---

### CPU layer offloads (`--ngl`) requirements

| Context Size (`-c`) | KV Cache (`--cache-k` & `--cache-v`) | Maximum `--ngl` |
| --- | --- | --- |
| 262144 | f16 | 44 |
| 262144 | q8_0 | 53 |
| 131072 | f16 | 57 |
| 131072 | q8_0 | 64 (no offload needed) |

Here both `--cache-k` and `--cache-v` were set to the same value, i.e. `q8_0` means both were set to `q8_0`.

The model has 64 total layers.

What surprised me the most was the difference between the second and the third test. I assumed the two should get similar if not the same result, turned the difference was significant.

If Kimi wasn't lying to me, this has something to do with llama.cpp's way of handling kv cache quantization, specifically speaking, a bit more memory is used for `q8_0` as metadata, making the total memory reduction slightly less than 50%.

### Speed test

Here only the two configs without kv quant were tested. As I don't plan to use kv quant in benchmarks or real world usage (I'd rather take model weight quantization over kv cache quantization), their speed means not much to me.

| `--ngl` | pp2048 | tg128 @ 2048 |
| --- | --- | --- |
| 44 | 876.5 | 5.441 |
| 57 | 1716 | 12.22 |

Unsurprisingly, the decode speed was not pretty. It's still acceptable for background tasks, but I doubt anyone would take the slight quality gain (exact comparison comming up soon) over the speed difference for any interactive task. For reference, I can get a tg128 of 57.78 with `Qwen3.6-27B-UD-Q6_K_XL.gguf`.