# PERSONAL.md — the personal cold starter

This fork is the **personal cold starter** of the DeepSeek Harness: it carries
the ensembled personal settings that turn a fresh checkout on a new machine
into a working dsh instance with a local LLM. The local-model plugins are no
longer shipped by the fork — they are installed per profile from their git
repositories with `dsh plugin add` (see
[Attaching a new personal plugin](#attaching-a-new-personal-plugin)). Everything
under `personal/` ships with the fork and is meant to be committed; runtime
state generated here is committed once it exists so the next clone reuses it.

## Change policy for this fork

The upstream codebase keeps its own conventions. To stay a bounded overlay,
the allowed changelist in the dsh repo is deliberately narrow, and today it is
**empty of personal plugin wiring**: the fork mounts no personal plugin rows
and declares no personal plugin dependencies. The personal plugins live
entirely outside the dsh repo:

- **in the plugin repositories** (`dsh-my-plugin-<name>`, each declaring
  `dsh.bundle` so `dsh plugin add` activates it as a profile layer), or
- **in `personal/`** (this document, notes, generated setup state).

No builtin dsh plugin is ever disabled by this fork; personal plugins are only
ever added, and only through the profile plugin mechanism.

## Layout

```
personal/
  PERSONAL.md                     this document
  start-web.ps1                   Windows entrypoint: rebuild, stop, and start
                                  `dsh web` (log at .dsh-web-log.txt)
  vllm/
    setup.json                    runtime setup state (committed once generated)
```

## The vLLM plugin — `dsh-my-plugin-vllm`

The local-model provider for servers with a proper GPU, installed into the web
profile as a bundle:

```sh
dsh plugin --profile web add github:laituli/dsh-my-plugin-vllm
```

The repository ships three packages: the virtual `dsh-my-plugin-vllm` bundle
(this package — it only declares `dsh.bundle.patch`, mounts the rows, and
depends on the other two), the host half `dsh-my-plugin-vllm-core`, and the
browser half `dsh-my-plugin-vllm-client` (a subdirectory of the same repo,
pulled in via pnpm's `#path:core` / `#path:client` git subfolder specs, pinned
in the profile lockfile). The bundle's `cordis.patch.yml` mounts the
`llm-vllm` (→ core) and `client-llm-vllm` (→ client) rows. All three ship
built `lib/` in their repo — pnpm installs them as-is, no `prepare` build runs
on install. While active the plugin:

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
  China mirror (china) through the container's `HF_ENDPOINT` — a real, stable
  mirror;
- the setup flow waits for the API, runs a **fixed-seed local call test**
  (seed 42 by default), and saves the selection to `personal/vllm/setup.json`
  in this repo;
- using the local model while setup is still required is refused with
  `SETUP_REQUIRED` (listing the catalog or booting never pops anything).

The plugin's own README (`dsh-my-plugin-vllm/README.md` in its repository)
owns its configuration fields and test command. Updates are package-manager
operations: `dsh plugin --profile web update dsh-my-plugin-vllm` re-resolves
the git ref and re-installs (the profile's `pnpm-lock.yaml` records the pinned
commit).

## Cold start on a new machine

```sh
git clone git@github.com:laituli/deepseek-harness.git
cd deepseek-harness
# One-time per machine: pnpm resolves `github:` specs through SSH, but this
# machine authenticates over HTTPS (credential manager). Rewrite SSH github
# URLs to HTTPS, or set up SSH keys instead.
git config url."https://github.com/".insteadOf "ssh://git@github.com/"
git config --add url."https://github.com/".insteadOf "git+ssh://git@github.com/"
pnpm install
dsh plugin --profile web install
pnpm dsh web
```

The web profile's manifest files are committed with the fork (see
[Saving the installed plugin set](#saving-the-installed-plugin-set)), so
`dsh plugin install` replays the whole plugin set — the exact dependencies,
bundle layers, and pinned commits — from `profiles/web/package.json` +
`profiles/web/pnpm-lock.yaml`; no per-plugin adds. It runs pnpm inside the
profile directory, so it needs `pnpm` on `PATH` and access to the plugin
repositories (private repos need GitHub credentials). The plugin ships built
`lib/` in its repo, so the install runs no build scripts.

The first time you use the local model, the chat overlay (opened by
`/vllm-setup`, or automatically when you select the local provider in the
model picker) walks you through the install; the durable configuration is
editable in Settings → Plugins → Plugin config. Complete the setup once and
the choice is saved to `personal/vllm/setup.json`, which the next clone
reuses.

## Saving the installed plugin set

`dsh plugin add` records the plugin set in the profile (`profiles/web/`), not
in any tracked file — a clone without the profile state would forget it. To
persist "these plugins are installed" in the repo:

1. Run the adds once on any machine:
   `dsh plugin --profile web add github:laituli/dsh-my-plugin-vllm`
   (the virtual bundle pulls the core and client halves in transitively; all
   ship built `lib/`, so no build scripts run on install).
2. Commit the profile's manifest files:
   `profiles/web/package.json` (the git dependency and the reconciled
   `dsh.profile.bundles` list), `profiles/web/pnpm-lock.yaml` (the pinned git
   commits, including the `path: core` / `path: client` subfolder fragments),
   and `profiles/web/cordis.patch.yml`. `.gitignore` un-ignores exactly these;
   everything else under `profiles/` (`node_modules`, the healed module
   fallback, the boot-rewritten `cordis.yml`) stays machine-local.
3. Every fresh clone replays the exact set with `dsh plugin --profile web
   install` — one command, no per-plugin adds.
4. To update a plugin: `dsh plugin --profile web update dsh-my-plugin-vllm`
   re-resolves the git ref, then commit the refreshed `pnpm-lock.yaml` so the
   next machine gets the same commit.

## Windows entrypoint

`powershell -ExecutionPolicy Bypass -File personal/start-web.ps1` (or
`.\personal\start-web.ps1` from an interactive PowerShell session) rebuilds and
restarts the GUI in one go: it sets the same environment the manual commands
do (local Node 22 first on PATH, XDG dirs and `DSH_HOME` inside the repo
tree), rebuilds the `apps/web` shell, materializes the web profile's recorded
plugin set (`dsh plugin --profile web install` — a no-op when the profile is
current, and it runs before the old server is stopped so a broken install
never takes the running GUI down), stops whatever dsh web listens on port
3080, and starts a fresh instance with the combined output teed to
`.dsh-web-log.txt`. The current GUI session disconnects during the swap;
refresh the browser tab once the new URL line appears. `-SkipShell` skips the
(slow) vite shell build. Ctrl+C stops the server.

## Attaching a new personal plugin

1. Create the private repo `dsh-my-plugin-<name>` and push its code. The
   top-level package declares
   `"dsh": { "bundle": { "patch": "./cordis.patch.yml" } }` and ships a
   `cordis.patch.yml` whose rows mount the plugin — that declaration is what
   makes `dsh plugin add` activate it as a profile layer. Split a dual-face
   plugin into `core/` + `client/` subdirectories and make the top-level
   package a virtual bundle that depends on them via
   `github:laituli/dsh-my-plugin-<name>#path:core` / `#path:client`, so one
   spec installs everything.
2. Make the packages installable from git: **commit built `lib/`** in the repo
   (and list it in `files`). A `prepare` build does NOT work for these
   plugins — pnpm runs `npm install` inside the fetched package first, and
   their build toolchain (`@deepseek-ai/*` workspace packages) is not on npm.
   Avoid `workspace:` protocol in `dependencies`/`peerDependencies` (it is
   invalid outside a workspace; use plain version ranges for harness-provided
   peers).
3. Install into the web profile:
   `dsh plugin --profile web add github:laituli/dsh-my-plugin-<name>`.
4. Commit the refreshed profile manifest files (see
   [Saving the installed plugin set](#saving-the-installed-plugin-set)) so
   every other machine gets the plugin with `dsh plugin --profile web
   install`.
5. Verify with the plugin's own test command.
