# Agent Note: Personal Ollama plugin on the fork

Status: implemented
Archived: 2026-08-20

English | [中文](2026-08-17-personal-ollama-plugin.zh.md)

## Problem

The personal fork (`laituli/deepseek-harness`) exists as a cold starter: a
fresh checkout should carry the ensembled personal settings and a working
local LLM, without depending on the upstream cloud provider. The fork also
wants to stay a bounded overlay — the dsh repo's allowed changelist is only
the plugin list and plugin activation — so the whole local-LLM capability has
to live outside the shipped package tree.

## Decision

The local LLM capability is an external plugin repository,
`dsh-my-plugin-ollama` (private, format `dsh-my-plugin-<name>`), attached to
the fork as a git submodule at `personal/plugins/dsh-my-plugin-ollama` and
registered as a workspace member for dependency resolution only. The dsh repo
change is exactly the allowed changelist:

- the web plugin list (`packages/bundle/web-app/cordis.patch.yml`) gains one
  row, `llm-ollama` naming the package; no builtin plugin is disabled;
- activation wiring: the submodule registration (`.gitmodules`), the
  `pnpm-workspace.yaml` membership, and `dsh-my-plugin-ollama` in
  `packages/bundle/web-app/package.json` `dependencies` (which puts the
  package into the profile module fallback closure, so the Loader resolves
  the row from any profile);
- one authorized `ui-settings-models` change: the Models page renders every
  provider card's editor through a keyed `settings.models.provider-editor`
  slot (key = provider route id, the generic `ProviderEditor` as fallback),
  so the Ollama setup form can live INSIDE Settings → Models as the
  provider's custom editor instead of a standalone Settings → Ollama (Local)
  section — the sibling-section placement was the one dissonant piece against
  the page's otherwise generic rows; absent an occupant the generic editor
  renders unchanged, so DeepSeek and pi-ai cards behave exactly as before;
- the personal docs (`personal/PERSONAL.md`, referenced from README and
  AGENTS.md) and this note.

The plugin itself owns the behavior: it registers the `ollama` provider route
on `ctx.llm` through the public adapter/directory/discovery seams, detects
OS/GPU/Ollama without blocking the event loop, and exposes the setup flow to
the web GUI as `ollamaSetup/status` and `ollamaSetup/submit` typert remotes
(the gateway's SRC discovery over a `TypertRemoteService`). The setup form
lives in the GUI — the Ollama provider's custom editor inside Settings →
Models, a `/ollama-setup` command, and a chat overlay from a small dedicated
client package — and the browser only ever
sees the setup surface when it actually sends a request to the provider before
setup: the request is refused with `SETUP_REQUIRED`; catalog listing, model
resolution, and boot never pop anything. The installation choice is defaulted
per OS with optional personalized installation and model-storage paths, saved
to `$DSH_HOME/personal/ollama/setup.json` in the repo. The model is picked by
GPU VRAM from the shipped Qwen 3.6 tiers and pulled during setup; the
fixed-seed local call test runs during setup submission (a boot-time test is
opt-in via `startupTest`, because loading the model into VRAM is a lag spike a
cold start should not pay). A separate local setup webpage remains only as a
headless fallback. The plugin repo ships its own real-composition test (a
throwaway profile boots the base bundle plus the plugin and a probe row
against a stub Ollama server).

## Alternatives considered

**Vendor the plugin as a `packages/` workspace package.** It would be built
and gated by the repo machinery, but it violates the fork's own change policy
(a package under `packages/` is far beyond the plugin list) and would fork the
upstream tree more deeply.

**Ship the plugin as a bundle added to the profile's `dsh.profile.bundles`.**
A bundle owns its patch layer, but the profile bundle list is runtime state
(`profiles/<name>/package.json`), not the tracked plugin list; a row in the
web bundle patch is the tracked, composable surface the fork already treats as
the plugin list.

**Configure the provider through the `llm-pi-ai` generic adapter.** No new
plugin at all. But pi-ai speaks OpenAI-compatible endpoints, Ollama's native
protocol (JSON-lines chat, tags, pull) needs its own adapter, and the setup
lifecycle (install, GPU-based model pick, fixed-seed test, setup page) has no
home in a generic profile.

## Consequences

The web provider list shows an `Ollama (Local)` route whenever the row is
active, and a fresh clone's first selection of that route walks a person
through the local setup in the browser — the boot itself stays quiet. The
fork gains one submodule whose private repo is a
hard dependency of the composed web profile: a clone without
`git submodule update --init` cannot resolve the row, which fails loud at
boot rather than silently. The plugin's build output (`lib/`) is a local
artifact, so a fresh clone must run the plugin build once; the cold-start
steps in `personal/PERSONAL.md` document that. CI on the fork runs the repo
gates; `verify-cordis-config` enforces that the new row's package is declared
in the web bundle manifest, which the activation wiring satisfies.
