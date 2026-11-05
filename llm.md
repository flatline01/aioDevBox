# Local coding LLM

A local LLM server (Ollama) and a browser chat UI (Open WebUI) on the `devstack` network, wired into VS Code on the linux desktop via the Continue extension.

```
 linux desktop (VS Code + Continue) ──┐
 Open WebUI  (http://open-webui:8080) ┼──► ollama:11434 ──► GPU
 host tools  (http://localhost:11434) ┘     (model files in the ollama_models volume)
```

Inside the desktop, the server is always `http://ollama:11434`, whichever GPU mode you choose.

## Quick start (Windows, Docker Desktop, WSL2, NVIDIA)

1. **Host prerequisites** (once)
   - Current NVIDIA driver installed **on Windows**. Do not install a driver inside WSL.
   - Docker Desktop using the WSL2 backend. Run `wsl --update` in PowerShell.
   - Check GPU passthrough: `docker run --rm --gpus all ubuntu nvidia-smi` should list your card.
2. **Add the variables** from the `.env` block below to your `.env`.
3. **Start it:** `docker compose up -d --build`. The `linux` image only needs a rebuild once, for the entrypoint change.
4. **Wait for the first model pull.** It downloads about 10 GB. Watch with `docker compose logs -f ollama-pull`. It ends with `== models ready`.
5. **Verify the GPU is in use:** `docker exec devstack_ollama ollama ps`. The PROCESSOR column should say `100% GPU`. If it shows CPU, see Gotchas.
6. **Use it**
   - VS Code in the desktop: open the Continue panel. Chat, edit and tab autocomplete are preconfigured.
   - Browser chat: http://localhost:8083 on the host, or http://open-webui:8080 in the desktop. The first account you create becomes the admin.

## `.env` block

```env
# --- Local LLM -------------------------------------------------------
# Which GPU variant to run. One of: nvidia | amd | cpu
# Leave EMPTY for host mode (Ollama installed natively on your machine).
COMPOSE_PROFILES=nvidia

# Which GPU(s). Index from nvidia-smi / rocm-smi. Comma-separate for several: 0,1
LLM_GPU_IDS=0

# Where containers find Ollama. Host mode: http://host.docker.internal:11434
LLM_BASE_URL=http://ollama:11434

# Models (see the sizing table below). Pulled automatically on start.
LLM_CHAT_MODEL=qwen2.5-coder:14b
LLM_AUTOCOMPLETE_MODEL=qwen2.5-coder:1.5b

# Ports (Ollama is published on 127.0.0.1 only)
OLLAMA_PORT=11434
OPEN_WEBUI_PORT=8083
OPEN_WEBUI_AUTH=true

# Image tags. Keep "latest" for new GPUs (e.g. RTX 50-series), then run
# `docker compose pull` now and then.
OLLAMA_TAG=latest
OLLAMA_ROCM_TAG=rocm
OPEN_WEBUI_TAG=main

# Tuning
OLLAMA_CONTEXT_LENGTH=8192
OLLAMA_KEEP_ALIVE=30m
OLLAMA_MAX_LOADED_MODELS=2
OLLAMA_NUM_PARALLEL=1
OLLAMA_FLASH_ATTENTION=1
OLLAMA_KV_CACHE_TYPE=q8_0
```

## Choosing a GPU mode

| Hardware | `COMPOSE_PROFILES` | Notes |
|---|---|---|
| NVIDIA, Windows (WSL2) or Linux | `nvidia` | Needs the NVIDIA driver on the host. On Linux also the NVIDIA Container Toolkit. |
| AMD, Linux host | `amd` | Uses `/dev/kfd` and `/dev/dri`. Cards ROCm doesn't officially support may need `HSA_OVERRIDE_GFX_VERSION` added to the `ollama-amd` environment. |
| AMD or Intel on **Windows**, Apple Silicon | *(empty)* = host mode | Containers can't reach these GPUs here. Install Ollama natively, set `LLM_BASE_URL=http://host.docker.internal:11434`, and pull models on the host with `ollama pull`. |
| No usable GPU | `cpu` | Works, but is slow. Use the 1.5B to 7B models. |

CPU matters only when a model doesn't fit in VRAM and spills into system RAM. With the default models on a 16 GB card, the CPU is not the bottleneck.

## Model sizing

Rough figures: Q4 quantization, about 8k context, one request at a time. KV cache grows with context length and `OLLAMA_NUM_PARALLEL`. Leave 1-2 GB of headroom, because Windows and the browsers also use VRAM. Check sizes on the Ollama pages before pulling.

| VRAM | Chat model | Autocomplete model |
|---|---|---|
| 8 GB | `qwen2.5-coder:7b` (~4.7 GB) | `qwen2.5-coder:1.5b` |
| 12 GB | `qwen2.5-coder:14b` (~9 GB), tight | `qwen2.5-coder:1.5b` |
| **16 GB (this machine)** | `qwen2.5-coder:14b` (~9 GB) | `qwen2.5-coder:1.5b` |
| 24 GB | a 22B to 32B coder model | `qwen2.5-coder:1.5b` or `:3b` |

The chat model and autocomplete model stay loaded together (`OLLAMA_MAX_LOADED_MODELS=2`). Autocomplete fires on nearly every keystroke, so it should be small and fast.

### Model notes and links

| Model | Good for | Link |
|---|---|---|
| Qwen2.5-Coder (1.5B to 32B) | The default. Solid general coding, many sizes | https://ollama.com/library/qwen2.5-coder |
| DeepSeek-Coder-V2 16B | Long context (MoE) | https://ollama.com/library/deepseek-coder-v2 |
| Codestral 22B | Code completion and fill-in-the-middle. Tight on 16 GB once context is added | https://ollama.com/library/codestral |
| Devstral 24B | Agentic coding. Borderline on 16 GB, better on 24 GB | https://ollama.com/library/devstral |
| gpt-oss 20B | General reasoning plus code. Offloads partly to system RAM on 16 GB | https://ollama.com/library/gpt-oss |
| Qwen3-Coder | Newer Qwen coder line. The main variant is too big for 16 GB without offload | https://ollama.com/library/qwen3-coder |

- Model lists change quickly. Treat this table as a starting point and compare against a current ranking, for example https://www.morphllm.com/best-ollama-models.
- For autocomplete, base (non-instruct) models usually complete better. If the library has a `:1.5b-base` tag for the model you use, try it. I haven't checked that the tag exists.
- To swap models: edit `LLM_CHAT_MODEL` / `LLM_AUTOCOMPLETE_MODEL` in `.env`, then `docker compose up -d ollama-pull linux` and restart the `linux` container.
- Disk: each model is several GB, stored in the `ollama_models` volume. Remove one with `docker exec devstack_ollama ollama rm <model>`.

## Gotchas

**Windows / WSL2 / NVIDIA**
- **Blackwell cards (RTX 50-series, such as your 5060 Ti):** these need a recent NVIDIA driver and a recent Ollama image. If `ollama ps` shows CPU or the server fails to see the GPU, update the driver, run `wsl --update`, then `docker compose pull`. There are reports of 5060 Ti CUDA problems in WSL that were about other software, not Ollama. See https://forums.developer.nvidia.com/t/blackwell-gpu-rtx-5060-ti-cuda-not-available-to-applications-in-wsl-despite-working-nvidia-smi/344426
- **Don't install an NVIDIA driver inside WSL.** The Windows driver is what passes through.
- **`nvidia-smi` works in WSL but Ollama uses CPU:** `docker exec devstack_ollama ollama ps` and `docker compose logs ollama-nvidia` show which GPU library loaded.
- **Disk:** WSL stores Docker data in a virtual disk (`docker_data.vhdx`) that grows with models and does not shrink by itself. Watch free space on C:.
- **RAM:** if a model spills out of VRAM, it uses WSL's RAM. The default WSL limit is about half of system RAM. Raise it in `%UserProfile%\.wslconfig` (`memory=`) if needed, then `wsl --shutdown`.

**Performance**
- **VRAM is shared** with Windows, Chrome and Firefox. A model that "fits" on paper can spill and slow down. Lower `OLLAMA_CONTEXT_LENGTH` or pick a smaller model.
- **Raising `OLLAMA_NUM_PARALLEL` multiplies KV cache memory.** Keep it at 1 for a single user.
- **First request after idle is slow** while the model loads. `OLLAMA_KEEP_ALIVE=30m` keeps it loaded.
- **Context length:** 8192 is a compromise. Bigger contexts help with large files but use much more VRAM.

**Project-specific**
- **The desktop doesn't wait for Ollama.** Unlike mysql, `linux` has no `depends_on` on it, because the first pull takes a long time. Until models finish, Continue shows connection or model-not-found errors.
- **The Continue config is regenerated on every boot** from `.env` (`~/.continue/config.yaml`). Change models in `.env`, not in that file. Continue's own state in `~/.continue` is not in a volume, so it is lost if the container is recreated.
- **The Continue extension installs at boot, not at build time.** The `.vscode` named volume hides anything installed into the image. The install runs in the background and needs internet. Look in `/var/log/devstack/continue-install.log` if it's missing.
- **Ollama's API has no authentication.** It's published on `127.0.0.1` only. Don't change that to `0.0.0.0` on a shared network.
- **Open WebUI:** the first account created becomes admin. Port 8083 avoids the Next.js dev port 3000. Model changes in Ollama appear in the UI after a refresh.
- **Only one GPU profile should be active.** The three Ollama services share a container name.
- **Host mode:** the `ollama-pull` service doesn't run, so pull models on the host (`ollama pull qwen2.5-coder:14b`).

## Commands

```bash
docker compose logs -f ollama-pull                 # model download progress
docker exec devstack_ollama ollama ps              # what's loaded, and on GPU or CPU
docker exec devstack_ollama ollama list            # downloaded models
docker exec devstack_ollama ollama rm <model>      # free disk
curl http://ollama:11434/api/tags                  # from inside the desktop
docker compose pull ollama-nvidia open-webui       # update images
```

## Links

- Ollama: https://ollama.com/ ; FAQ and env vars: https://github.com/ollama/ollama/blob/main/docs/faq.md ; GPU support: https://github.com/ollama/ollama/blob/main/docs/gpu.md
- Continue (VS Code extension): https://docs.continue.dev/
- Open WebUI: https://docs.openwebui.com/
- Docker Desktop GPU support: https://docs.docker.com/desktop/features/gpu/
- CUDA on WSL: https://docs.nvidia.com/cuda/wsl-user-guide/index.html