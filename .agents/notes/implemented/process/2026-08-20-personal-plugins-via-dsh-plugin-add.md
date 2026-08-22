# Agent Note: Personal fork installs its plugins via dsh plugin add

Status: implemented

English | [中文](2026-08-20-personal-plugins-via-dsh-plugin-add.zh.md)

## Problem

The personal fork (`laituli/deepseek-harness`) shipped its local-model
plugins as git submodules plus workspace members plus web-bundle
dependencies, with the plugin rows in the tracked web bundle patch (the
attachment of the first one is the archived
[Personal Ollama plugin note](../../archived/feature/2026-08-17-personal-ollama-plugin.md);
the Ollama plugin is since removed, see
[the removal note](../simplification/2026-08-20-personal-ollama-plugin-removed.md)).
That model kept the fork's changelist (plugin list + activation wiring)
carrying the plugins, and every update was a submodule push plus a fork
bump. The standard dsh distribution path is different: installable profile
bundles added with `dsh plugin --profile <name> add <git-spec>`, where the
package manager owns source acquisition, versions, and the lockfile. The
fork's author wants the remaining plugin — `dsh-my-plugin-vllm` — consumed
that way.

## Decision

The vLLM plugin is converted from fork-shipped wiring to a profile-installed
bundle, and the fork stops carrying personal plugin wiring altogether:

- the web bundle patch (`packages/bundle/web-app/cordis.patch.yml`) drops the
  personal rows (`llm-vllm`, `client-llm-vllm`); the rows now ship in the
  plugin's own patch — the plugin declares
  `"dsh": { "bundle": { "patch": "./cordis.patch.yml" } }`, which is what
  makes `dsh plugin add` activate it as a profile layer;
- the activation wiring is removed: `dsh-my-plugin-vllm` /
  `dsh-my-plugin-vllm-client` leave `packages/bundle/web-app/package.json`
  `dependencies` and `pnpm-workspace.yaml`, and the submodule registration is
  deleted (`.gitmodules`, the gitlinks, and the deinitialized working trees);
- installation is per profile, one spec:
  `dsh plugin --profile web add github:laituli/dsh-my-plugin-vllm` — the
  repository ships three packages: the virtual `dsh-my-plugin-vllm` bundle
  (the profile layer; it only declares `dsh.bundle.patch` and depends on the
  other two), the host half `dsh-my-plugin-vllm-core` (`core/`), and the
  browser half `dsh-my-plugin-vllm-client` (`client/`, a subdirectory of the
  same repository). The bundle pulls the halves in through pnpm's
  `#path:core` / `#path:client` git subfolder specs (the subfolder fragments
  live in the profile's lockfile);
- the plugin packages ship **committed built `lib/`** — no `prepare` build
  runs on install. A `prepare` build cannot work for these plugins: pnpm runs
  `npm install` inside the fetched package first, and their build toolchain
  (`@deepseek-ai/*` workspace packages) is not on npm. The manifests also
  avoid the `workspace:` protocol in `dependencies`/`peerDependencies`
  (invalid outside a workspace), using plain version ranges for
  harness-provided peers;
- the personal docs (`personal/PERSONAL.md`, `personal/start-web.ps1`)
  describe the vllm-only, profile-installed cold start.

## Alternatives considered

**Keep the submodule/workspace wiring.** The fork keeps shipping the plugin,
and updates stay submodule-push plus fork-bump operations; the fork's
changelist keeps growing for plugin maintenance. Rejected: the author wants
the package-manager model.

**Declare git dependencies in the web bundle.** Putting
`github:laituli/dsh-my-plugin-vllm` directly in
`packages/bundle/web-app/package.json` satisfies `verify-cordis-config`
(the gate requires every bundle-patch row to be declared in that bundle's
dependencies) while keeping the rows tracked — but the plugin is then part
of every clone's workspace install, not a profile-managed plugin. Rejected:
the author wants the `dsh plugin add` flow.

**Keep the rows in the fork's bundle patch without declaring the
dependencies.** Fails `verify-cordis-config`, which the fork's CI runs;
rejected. Moving the rows into the plugin's own patch (the chosen design)
sidesteps the gate entirely because the gate only scans tracked
`packages/bundle/*` patches.

## Consequences

- The fork's tracked state contains no personal plugin rows, dependencies,
  workspace members, or submodules; `verify-cordis-config` has nothing
  personal to check.
- A fresh clone has no local provider until `dsh plugin add` runs — the rows
  exist only in the installed bundle's patch. If the bundle is installed but
  its browser half is not, the `client-llm-vllm` row fails loud at boot.
- Updates are package-manager operations:
  `dsh plugin --profile web update dsh-my-plugin-vllm` re-resolves the git
  ref; the profile's `pnpm-lock.yaml` records the pinned commit.
- The plugin repositories must be git-installable by shipping committed
  `lib/` (the plugin repos are outside the fork's changelist, so that work
  happens in `dsh-my-plugin-vllm` itself). `github:` specs resolve through
  SSH by default; machines that authenticate over HTTPS need a one-time
  `url."https://github.com/".insteadOf` rewrite (or SSH keys).

## Testing

A repo-wide search finds no active reference to the personal rows
(`llm-vllm`, `client-llm-vllm`), the personal packages, or the submodule
paths outside the archived and current Agent Notes; the rows live only in the
plugin repository's `cordis.patch.yml`.
