# Agent Note: Personal fork installs its plugins via dsh plugin add

Status: implemented

[English](2026-08-20-personal-plugins-via-dsh-plugin-add.md) | 中文

## Problem

个人分支（`laituli/deepseek-harness`）此前以「git 子模块 + 工作区成员 + web bundle 依赖」的方式携带本地大模型插件，插件行位于被跟踪的 web bundle 补丁中（首个插件的接入记录见已归档的[个人 Ollama 插件笔记](../../archived/feature/2026-08-17-personal-ollama-plugin.md)；Ollama 插件已被移除，见[移除笔记](../simplification/2026-08-20-personal-ollama-plugin-removed.md)）。这种模型让分支的变更清单（插件列表 + 激活接线）持续背负插件，每次更新都是一次子模块推送加分支版本号提升。而 dsh 的标准分发路径不同：通过 `dsh plugin --profile <name> add <git-spec>` 安装可安装的 profile bundle，由包管理器负责源码获取、版本与锁文件。分支作者希望剩余的插件——`dsh-my-plugin-vllm`——以这种方式被消费。

## Decision

vLLM 插件从分支携带的接线转换为 profile 安装的 bundle，分支彻底停止携带个人插件接线：

- web bundle 补丁（`packages/bundle/web-app/cordis.patch.yml`）删除个人行（`llm-vllm`、`client-llm-vllm`）；这些行改由插件自身的补丁携带——插件声明 `"dsh": { "bundle": { "patch": "./cordis.patch.yml" } }`，这正是 `dsh plugin add` 将其激活为 profile 层的依据；
- 激活接线被移除：`dsh-my-plugin-vllm` / `dsh-my-plugin-vllm-client` 退出 `packages/bundle/web-app/package.json` 的 `dependencies` 与 `pnpm-workspace.yaml`，子模块注册被删除（`.gitmodules`、gitlink 与反初始化的工作树）；
- 安装按 profile 进行：`dsh plugin --profile web add github:laituli/dsh-my-plugin-vllm github:laituli/dsh-my-plugin-vllm#path:client`——根包作为 bundle 层激活，浏览器半（`dsh-my-plugin-vllm-client`，同一仓库的子目录）通过 pnpm 的 `#path:client` git 子目录 spec 一并安装（子目录片段记录在 profile 的锁文件中）；
- 插件包**提交构建好的 `lib/`**——安装时不运行 `prepare` 构建。`prepare` 构建对这些插件不可行：pnpm 会先在取回的包内运行 `npm install`，而它们的构建工具链（`@deepseek-ai/*` 工作区包）并不在 npm 上。清单也避免在 `dependencies`/`peerDependencies` 中使用 `workspace:` 协议（在非工作区环境中无效），改用普通版本范围声明由 harness 提供的 peers；
- 个人文档（`personal/PERSONAL.md`、`personal/start-web.ps1`）描述仅 vLLM、profile 安装的冷启动流程。

## Alternatives considered

**保留子模块/工作区接线。** 分支继续携带插件，更新仍是子模块推送加分支版本号提升；分支的变更清单因插件维护而持续膨胀。否决：作者想要包管理器模型。

**在 web bundle 中声明 git 依赖。** 把 `github:laituli/dsh-my-plugin-vllm` 直接写进 `packages/bundle/web-app/package.json` 可以满足 `verify-cordis-config`（该门禁要求 bundle 补丁的每一行都声明在该 bundle 的依赖中）同时保留被跟踪的行——但插件会进入每次克隆的工作区安装，而非 profile 管理的插件。否决：作者要的是 `dsh plugin add` 流程。

**保留分支 bundle 补丁中的行但不声明依赖。** 会让 `verify-cordis-config`（分支 CI 会运行）失败；否决。把行移入插件自身的补丁（所选设计）完全绕开门禁，因为门禁只扫描被跟踪的 `packages/bundle/*` 补丁。

## Consequences

- 分支的被跟踪状态不再包含个人插件行、依赖、工作区成员或子模块；`verify-cordis-config` 没有个人内容需要检查。
- 全新检出在运行 `dsh plugin add` 之前没有本地提供商——行只存在于已安装 bundle 的补丁中。若 bundle 已安装但其浏览器半未安装，`client-llm-vllm` 行会在启动时响亮失败。
- 更新是包管理器操作：`dsh plugin --profile web update dsh-my-plugin-vllm` 会重新解析 git ref；profile 的 `pnpm-lock.yaml` 记录固定的 commit。
- 插件仓库必须通过提交 `lib/` 实现可被 git 安装（插件仓库不在分支的变更清单内，因此该工作在 `dsh-my-plugin-vllm` 自身完成）。`github:` spec 默认走 SSH；通过 HTTPS 认证的机器需要一次性 `url."https://github.com/".insteadOf` 改写（或配置 SSH 密钥）。

## Testing

全仓库搜索除已归档与现行的 Agent Note 外，找不到对个人行（`llm-vllm`、`client-llm-vllm`）、个人包或子模块路径的活动引用；这些行只存在于插件仓库的 `cordis.patch.yml` 中。
