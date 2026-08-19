# PERSONAL.md — the personal cold starter

This fork is the **personal cold starter** of the DeepSeek Harness: it carries
the ensembled personal settings and plugins that turn a fresh checkout on a
new machine into a working dsh instance with a local LLM. Everything under
`personal/` ships with the fork and is meant to be committed; runtime state
generated here is committed once it exists so the next clone reuses it.

## Change policy for this fork

The upstream codebase keeps its own conventions. To stay a bounded overlay,
the allowed changelist in the dsh repo is deliberately narrow:

1. **the plugin list** — the rows mounted for a profile (the web bundle patch
   at `packages/bundle/web-app/cordis.patch.yml`) and
2. **plugin activation** — the manifest wiring that makes those rows resolve
   (`pnpm-workspace.yaml` membership, the bundle's `dependencies`, the git
   submodule registration).

Everything else lives, in order of preference:

- **in the plugin repo** (`dsh-my-plugin-<name>` git submodules under
  `personal/plugins/`), or
- **in `personal/`** (this document, notes, generated setup state).

No builtin dsh plugin is ever disabled by this fork; the personal rows only
add.

## Layout

```
personal/
  PERSONAL.md                     this document
  plugins/                        git submodules, one repo per personal plugin
    dsh-my-plugin-ollama/         the local Ollama LLM provider
    dsh-my-plugin-vllm/           the local vLLM provider (Docker-first)
  ollama/
    setup.json                    runtime setup state (committed once generated)
  vllm/
    setup.json                    runtime setup state (committed once generated)
```

## The Ollama plugin — `dsh-my-plugin-ollama`

Attached to the web plugin list as the `llm-ollama` row (see
`packages/bundle/web-app/cordis.patch.yml`). While active it:

- registers the `ollama` provider in the dsh model provider list, with the
  chosen model advertised under it;
- detects the OS, the GPU (nvidia-smi, then platform fallbacks), and whether
  the Ollama server answers;
- the setup form lives **inside the dsh GUI** (the `/ollama-setup` command and
  a chat overlay, driven by the `ollamaSetup/status` + `ollamaSetup/submit` +
  `ollamaSetup/redetect` remotes): it shows the detected OS/GPU/Ollama facts,
  pre-selects the OS-appropriate installation method and the GPU-suggested
  model (shipped tiers prefer the **Qwen 3.6** series), and submits the
  choices, including optional personalized installation and model storage
  (`OLLAMA_MODELS`) paths; the separate local setup webpage remains only as a
  headless fallback;
- the durable configuration (endpoint, model, install timing, personalized
  paths) is editable as a config card in **Settings → Plugins → Plugin
  config**, staged over the `dsh-my-plugin-ollama` settings section;
- the setup flow installs Ollama (or skips on manual/none), waits for the
  server, pulls the chosen model, runs a **fixed-seed local call test**
  (seed 42 by default) during submission, and saves the selection to
  `personal/ollama/setup.json` in this repo;
- on every start after setup, re-verifies the model and (when `startupTest` is
  enabled) re-runs the fixed-seed test, logging the result;
- using the local model while setup is still required is refused with
  `SETUP_REQUIRED` (listing the catalog or booting never pops anything), so a
  cold start stays quiet until you ask the local model to work.

The plugin's own README (`personal/plugins/dsh-my-plugin-ollama/README.md`)
owns its configuration fields and test command.

## The vLLM plugin — `dsh-my-plugin-vllm`

Attached to the web plugin list as the `llm-vllm` row (see
`packages/bundle/web-app/cordis.patch.yml`). It is the sibling local-model
provider for servers with a proper GPU: while active it:

- registers the `vllm` provider in the dsh model provider list, advertising
  the served OpenAI-compatible models;
- detects the OS, the GPU, whether docker answers, and whether the vLLM API is
  reachable;
- the setup form lives **inside the dsh GUI** (the `/vllm-setup` command and a
  chat overlay, driven by the `vllmSetup/status` + `vllmSetup/submit` +
  `vllmSetup/redetect` remotes);
- the durable configuration (model, HF source, port, cache path, lifecycle
  timings) is editable as a config card in **Settings → Plugins → Plugin
  config**, staged over the `dsh-my-plugin-vllm` settings section;
- **Docker-first deployment**: it generates (and, when docker answers, runs)
  the `docker run` command for `vllm/vllm-openai`, mapping the API port and
  passing `--gpus all` when a NVIDIA GPU was detected; `manual` mode covers an
  already-running server;
- models are downloaded from **HuggingFace** (global) or the **hf-mirror.com**
  China mirror (china) through the container's `HF_ENDPOINT` — a real,
  stable mirror, unlike Ollama's registry situation;
- the setup flow waits for the API, runs a **fixed-seed local call test**
  (seed 42 by default), and saves the selection to `personal/vllm/setup.json`
  in this repo;
- using the local model while setup is still required is refused with
  `SETUP_REQUIRED` (listing the catalog or booting never pops anything).

The plugin's own README (`personal/plugins/dsh-my-plugin-vllm/README.md`)
owns its configuration fields and test command.

## Cold start on a new machine

```sh
git clone git@github.com:laituli/deepseek-harness.git
cd deepseek-harness
git submodule update --init --recursive
pnpm install
pnpm --filter dsh-my-plugin-ollama run build
pnpm --filter dsh-my-plugin-ollama-client run build
pnpm --filter dsh-my-plugin-vllm run build
pnpm --filter dsh-my-plugin-vllm-client run build
pnpm dsh web
```

The first time you use the local model, the chat overlay (opened by
`/ollama-setup` / `/vllm-setup`, or automatically when you select the local
provider in the model picker) walks you through the install; the durable
configuration is editable in Settings → Plugins → Plugin config. Complete the
setup once and the choice is saved to `personal/ollama/setup.json` (or
`personal/vllm/setup.json`), which the next clone reuses.

## Attaching a new personal plugin

1. Create the private repo `dsh-my-plugin-<name>` and push its code.
2. `git submodule add <url> personal/plugins/dsh-my-plugin-<name>`.
3. Add the directory to `packages:` in `pnpm-workspace.yaml`.
4. Add the package to `dependencies` in `packages/bundle/web-app/package.json`
   (so the profile module fallback can resolve it).
5. Add the plugin row to the web plugin list in
   `packages/bundle/web-app/cordis.patch.yml`.
6. `pnpm install`, rebuild the plugin, verify with
   `pnpm --filter dsh-my-plugin-<name> run test`.
