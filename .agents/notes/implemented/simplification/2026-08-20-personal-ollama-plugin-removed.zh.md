# Agent Note: Personal fork drops the Ollama plugin

Status: implemented

[English](2026-08-20-personal-ollama-plugin-removed.md) | 中文

## Problem

个人分支（`laituli/deepseek-harness`）是冷启动器，其 web 插件列表挂载了两个本地大模型提供商：`dsh-my-plugin-ollama` 与 `dsh-my-plugin-vllm`（前者的接入记录见已归档的[个人 Ollama 插件笔记](../../archived/feature/2026-08-17-personal-ollama-plugin.md)）。分支只需要一个本地提供商，而实际使用的是 vLLM——Docker 优先部署，模型来自 HuggingFace / hf-mirror。处于非激活状态的 Ollama 插件仍然让每次克隆都要拉取一个子模块、每次 `pnpm install` 都要构建一个工作区包、web profile 也要多一份依赖闭包，而分支从不选择该提供商。

## Decision

`dsh-my-plugin-ollama` 及其浏览器半被从分支的激活集合中移除——这是接入时变更清单的逆向操作：

- web 插件列表（`packages/bundle/web-app/cordis.patch.yml`）删除 `llm-ollama` 与 `client-llm-ollama` 两行，个人行只保留 `llm-vllm` 与 `client-llm-vllm`；
- 激活接线被拆除：git 子模块注册（`.gitmodules`）、`pnpm-workspace.yaml` 成员条目，以及 `packages/bundle/web-app/package.json` `dependencies` 中的 `dsh-my-plugin-ollama` / `dsh-my-plugin-ollama-client` 全部移除，子模块工作树已反初始化；
- 个人文档（`personal/PERSONAL.md`、`personal/start-web.ps1`）描述仅 vLLM 的冷启动流程。

插件仓库仍存在于 GitHub（`laituli/dsh-my-plugin-ollama`）：能力从分支移除，而非在上游删除。`personal/PERSONAL.md` 中的「Attaching a new personal plugin」流程就是重新接入的路径。

## Alternatives considered

**保留行但禁用。** `disabled: true` 行可以阻止挂载，但插件仍是工作区成员与子模块：每次克隆仍会拉取它，每次 `pnpm install` 仍会构建它。「只需要 vllm」是对分支形态的陈述，因此完整移除更符合分支的变更策略（插件列表及其激活接线）。

**两个插件都保留。** 在没有合适 GPU 的机器上 Ollama 仍是更轻的选择，但分支的目标机器运行 vLLM；一个从不选用的提供商仍然让分支付出子模块、构建与依赖闭包的代价。

## Consequences

web 提供商列表只显示 `vllm` 路由；`ollama` 路由、`/ollama-setup` 命令与 Ollama 设置界面从分支消失。全新检出不再拉取或构建 Ollama 插件。接入笔记所授权的 `settings.models.provider-editor` slot 保留在主仓库中；没有占用者时通用编辑器原样渲染，而回退它超出了本分支允许的变更清单。没有任何活动的代码、配置或文档引用 ollama 行或包；仅有的提及是已归档的接入笔记与本笔记。

## Testing

静态门禁会拒绝过时引用：`verify-cordis-config` 不再看到 ollama 行，工作区图移除 ollama 成员，全仓库搜索除已归档的接入笔记与本笔记外找不到任何对 ollama 行、包或子模块路径的活动引用。
