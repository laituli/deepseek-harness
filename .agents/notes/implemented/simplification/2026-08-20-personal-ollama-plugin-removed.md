# Agent Note: Personal fork drops the Ollama plugin

Status: implemented

English | [中文](2026-08-20-personal-ollama-plugin-removed.zh.md)

## Problem

The personal fork (`laituli/deepseek-harness`) is a cold starter whose web
plugin list carried two local-model providers, `dsh-my-plugin-ollama` and
`dsh-my-plugin-vllm` (the attachment of the former is the archived
[Personal Ollama plugin note](../../archived/feature/2026-08-17-personal-ollama-plugin.md)).
The fork needs exactly one local provider, and vLLM's Docker-first deployment
with a HuggingFace / hf-mirror model source is the one in use. The inactive
Ollama plugin still cost every clone a submodule fetch, every `pnpm install`
a workspace build, and the web profile a dependency closure, for a provider
the fork never selects.

## Decision

The `dsh-my-plugin-ollama` plugin and its browser half are removed from the
fork's active set — the reverse of the attachment changelist:

- the web plugin list (`packages/bundle/web-app/cordis.patch.yml`) drops the
  `llm-ollama` and `client-llm-ollama` rows, leaving `llm-vllm` and
  `client-llm-vllm` as the only personal rows;
- the activation wiring is unwired: the git submodule registration
  (`.gitmodules`), the `pnpm-workspace.yaml` membership, and the
  `dsh-my-plugin-ollama` / `dsh-my-plugin-ollama-client` entries in
  `packages/bundle/web-app/package.json` `dependencies` are removed, and the
  submodule working tree is deinitialized;
- the personal docs (`personal/PERSONAL.md`, `personal/start-web.ps1`)
  describe the vllm-only cold start.

The plugin repositories still exist on GitHub
(`laituli/dsh-my-plugin-ollama`); the capability is gone from the fork, not
deleted upstream. The "Attaching a new personal plugin" procedure in
`personal/PERSONAL.md` is the reintroduction path.

## Alternatives considered

**Keep the rows but disable them.** A `disabled: true` row would stop the
mount, but the plugin would remain a workspace member and a submodule: every
clone would still fetch it and every `pnpm install` would still build it.
"Only vllm" is a fork-shape statement, so the removal matches the fork's
change policy (the plugin list plus its activation wiring).

**Keep both plugins.** Ollama remains the lighter option for machines without
a proper GPU, but the fork's target machines run vLLM, and an unused provider
still costs the fork a submodule, a workspace build, and a dependency closure
for no selection.

## Consequences

The web provider list shows only the `vllm` route; the `ollama` route, the
`/ollama-setup` command, and the Ollama settings surface are gone from the
fork. A fresh clone no longer fetches or builds the Ollama plugin. The
`settings.models.provider-editor` slot the attachment note authorized stays in
the main repo; without an occupant it renders the generic editor unchanged,
and reverting it is outside this fork's allowed changelist. No active code,
configuration, or documentation references the ollama rows or packages; the
only remaining mentions are the archived attachment note and this note.

## Testing

The static gates reject stale references: `verify-cordis-config` sees no
ollama rows, the workspace graph drops the ollama members, and a repo-wide
search finds no active reference to the ollama rows, packages, or submodule
path outside the archived attachment note and this note.
