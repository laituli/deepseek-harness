# Agent Note: Personal Ollama plugin on the fork

Status: implemented

[English](2026-08-17-personal-ollama-plugin.md) | 中文

## Problem

个人分支（`laituli/deepseek-harness`）的定位是冷启动器：一份全新的检出应当自带整理好的个人设置与可用的本地大模型，而不依赖上游的云端提供商。同时该分支希望保持有界的覆盖——dsh 仓库的允许变更清单只有插件列表与插件激活——因此整个本地大模型能力必须落在官方包树之外。

## Decision

本地大模型能力是一个外部插件仓库 `dsh-my-plugin-ollama`（私有，命名格式 `dsh-my-plugin-<name>`），作为 git 子模块挂在 `personal/plugins/dsh-my-plugin-ollama`，并注册为仅用于依赖解析的工作区成员。dsh 仓库的改动恰好是允许的变更清单：

- web 插件列表（`packages/bundle/web-app/cordis.patch.yml`）新增一行 `llm-ollama`，指向该包；不关闭任何内置插件；
- 激活接线：子模块注册（`.gitmodules`）、`pnpm-workspace.yaml` 成员条目，以及 `packages/bundle/web-app/package.json` 的 `dependencies` 中的 `dsh-my-plugin-ollama`（这会把该包放入 profile 模块回退闭包，使 Loader 能从任意 profile 解析这一行）；
- 个人文档（`personal/PERSONAL.md`，由 README 与 AGENTS.md 引用）与本笔记。

插件自身拥有全部行为：它通过公开的 adapter / directory / discovery 接缝在 `ctx.llm` 上注册 `ollama` 提供商路由；检测操作系统 / GPU / Ollama；当需要设置时打开一个本地临时设置页（安装方式按操作系统给出默认并保存到仓库内的 `$DSH_HOME/personal/ollama/setup.json`）；按 GPU 显存挑选模型；拉取模型；启动时运行固定种子本地调用测试；若消费者在设置完成前选择该提供商，则重新弹出设置页。插件仓库自带真实组合测试（一个临时 profile 引导 base 包外加插件与探针行，对接到一个 Ollama 桩服务器）。

## Alternatives considered

**把插件作为 `packages/` 下的工作区包内置。** 它会得到仓库机制的全部构建与门禁，但违反分支自身的变更策略（`packages/` 下的包远超插件列表），并会更深地分叉上游树。

**把插件作为 bundle 加入 profile 的 `dsh.profile.bundles`。** bundle 拥有自己的补丁层，但 profile 的 bundle 列表是运行时状态（`profiles/<name>/package.json`），不是被跟踪的插件列表；web bundle 补丁中的一行才是分支视为插件列表的、被跟踪且可组合的表面。

**通过 `llm-pi-ai` 通用适配器配置该提供商。** 完全不需要新插件。但 pi-ai 只讲 OpenAI 兼容端点，Ollama 的原生协议（JSON 行聊天、tags、pull）需要自己的适配器，而且设置生命周期（安装、按 GPU 选模型、固定种子测试、设置页）在通用 profile 里没有容身之处。

## Consequences

只要该行处于激活状态，web 提供商列表就会显示 `Ollama (Local)` 路由；全新检出首次启动时会在浏览器里引导用户完成本地设置。分支因此多了一个子模块，其私有仓库是组合后的 web profile 的硬依赖：未执行 `git submodule update --init` 的检出无法解析这一行，会在启动时响亮失败而非静默跳过。插件的构建产物（`lib/`）是本地产物，全新检出需要先构建一次插件；`personal/PERSONAL.md` 中的冷启动步骤记录了这一点。分支上的 CI 会运行仓库门禁；`verify-cordis-config` 强制新行的包必须声明在 web bundle 的 manifest 中，激活接线已满足该要求。
