# 🤖 Agent 协作交接手册 (Agent Handoff Manual)

**最后更新**: 2026-02-11
**目标读者**: 接手项目的 AI Agent (Gemini, Claude, DeepSeek 等) 及开发者
**项目环境**: OpenClaw 部署于 Zeabur (PaaS)

此文档旨在帮助后续的 Agent 快速理解本项目特殊的部署环境与环境变量配置，防止因环境差异导致服务崩溃。

---

## 🇨🇳 第一部分：中文版 (Chinese Version)

### 1. 🔑 环境变量全集 (Environment Variables)

**⚠️ 严重警告**: 以下变量必须在 **Zeabur 后台 -> Settings -> Variables** 中配置。**严禁**将这些密钥硬编码在代码库的文件中！

| 变量名 (Key) | 用途说明 | 重要性 | 示例格式 / 备注 |
| :--- | :--- | :--- | :--- |
| `OPENROUTER_API_KEY` | **模型密钥**。OpenClaw 用它来调用 Gemini/Claude 进行思考。 | 🔴 **极高** | `sk-or-v1-cr-...` (必须支持 OpenRouter) |
| `OPENCLAW_GATEWAY_TOKEN` | **认证令牌**。保护 Dashboard 和 WebSocket 连接的安全密码。 | 🔴 **极高** | `MySecretString123` (体现在 URL 参数 `?token=...` 中) |
| `TELEGRAM_BOT_TOKEN` | **Telegram 机器人密钥**。(当前**已禁用**，防止无效 Token 导致无限重启)。 | 🟡 中等 | `123456:ABC-DEF...` (仅在 `openclaw.zeabur.json` 开启 TG 时需要) |
| `BRAVE_SEARCH_API_KEY` | **联网搜索密钥**。允许 Agent 搜索实时互联网信息。 | 🟡 中等 | `BS...` (用于 `tools.web.search`) |
| `PORT` | **服务端口**。Zeabur 路由流量的端口。 | 🟢 系统级 | `8080` (在 Dockerfile 中已固定) |
| `NODE_ENV` | **运行环境**。 | 🟢 系统级 | `production` |

### 2. 🏗️ 架构与文件系统 (特殊机制)

**致未来的 Agent，请仔细阅读以下机制，这与标准 Docker 不同：**

1.  **独有的“强制重置”逻辑 (Force Reset)**:
    *   **问题**: Zeabur 会持久化保留 `/home/node/.openclaw` 目录。如果里面残留了旧的、错误的配置文件，你即使推送了新的 Git 代码，服务读取的还是旧配置，导致部署失败。
    *   **解决方案**: 我们的启动脚本 (`docker-entrypoint.sh`) 写死了逻辑：**每次启动时，强制删除持久化目录里的 `openclaw.json`**。
    *   **你的行动准则**: **Git 代码是唯一真理**。不要试图 SSH 进容器修改文件，也不要指望容器重启后文件还在。**修改 `openclaw.zeabur.json` 并推送到仓库**，才是唯一正确的修改方式。

2.  **容器内关键路径**:
    *   配置文件: `/home/node/.openclaw/openclaw.json` (由启动脚本生成)
    *   聊天记录: `/home/node/.openclaw/workspace` (只有这个目录是真正持久化且安全的)
    *   浏览器文件: `/home/node/.openclaw/playwright` (持久化保留的大文件)

### 3. 🚨 故障救援协议 (Rescue Protocol)

**如果遇到 502 Bad Gateway 或 Crash Loop (无限重启):**

1.  **不要盲目改代码**。先检查 **Zeabur 变量** 是否漏填了 `OPENROUTER_API_KEY`。
2.  **检查配置文件 (`openclaw.zeabur.json`)**:
    *   是否有 `tools.browser`? -> **删掉它** (它会导致 Schema 校验失败)。
    *   是否有 `_config_version`? -> **删掉它**。
    *   `telegram.enabled` 是 `true`? -> **检查 Token** 或 **改为 `false`**。
3.  **使用"黄金备份"恢复**:
    *   路径: `backup_2026-02-10_Golden_State/GOLDEN_CONFIG.md`
    *   操作: 将该文件中的代码完整覆盖回根目录，提交推送。

---
---

## 🇺🇸 Part 2: English Version

### 1. 🔑 Environment Variables Registry

**CRITICAL WARNING**: These variables MUST be set in the **Zeabur Dashboard -> Settings -> Variables** section. **NEVER** hardcode these keys in the repository files!

| Variable Name (Key) | Description | Criticality | Example Format / Notes |
| :--- | :--- | :--- | :--- |
| `OPENROUTER_API_KEY` | **LLM API Key**. Used by OpenClaw to talk to Gemini/Claude. | 🔴 **High** | `sk-or-v1-cr-...` (Must support OpenRouter) |
| `OPENCLAW_GATEWAY_TOKEN` | **Auth Token**. Password protecting the Dashboard & Websocket. | 🔴 **High** | `MySecretString123` (Visible in URL `?token=...`) |
| `TELEGRAM_BOT_TOKEN` | **Telegram Bot Token**. (Currently **DISABLED** to prevent crash loops from invalid tokens). | 🟡 Medium | `123456:ABC-DEF...` (Only needed if `openclaw.zeabur.json` enables Telegram) |
| `BRAVE_SEARCH_API_KEY` | **Web Search Key**. Allows the agent to search the internet. | 🟡 Medium | `BS...` (Required for `tools.web.search`) |
| `PORT` | **Service Port**. Zeabur expects this port for routing. | 🟢 System | `8080` (Fixed in Dockerfile) |
| `NODE_ENV` | **Runtime Environment**. | 🟢 System | `production` |

### 2. 🏗️ Architecture & Filesystem (Special Mechanism)

**To Future Agents, please read this carefully as it differs from standard Docker:**

1.  **Unique "Force Reset" Logic**:
    *   **The Problem**: Zeabur persists the `/home/node/.openclaw` volume. If an old, broken config remains there, redeploying code *will not* take effect, leading to persistent failures.
    *   **The Solution**: Our startup script (`docker-entrypoint.sh`) has hardcoded logic: **Forcefully delete `openclaw.json` in the persistent volume on every startup.**
    *   **Action Item**: **Git is the only Source of Truth.** Do NOT try to ssh into the container to fix files. **Modify `openclaw.zeabur.json` in the repo and push.**

2.  **Key Container Paths**:
    *   Config File: `/home/node/.openclaw/openclaw.json` (Generated by entrypoint)
    *   Workspace: `/home/node/.openclaw/workspace` (The ONLY path that is truly safe and persisted for data)
    *   Browsers: `/home/node/.openclaw/playwright` (Persisted binaries)

### 3. 🚨 Rescue Protocol

**If you encounter 502 Bad Gateway or Crash Loops:**

1.  **DON'T panic-code**. Check **Zeabur Variables** first. Is `OPENROUTER_API_KEY` missing?
2.  **Check `openclaw.zeabur.json`**:
    *   Exists `tools.browser`? -> **DELETE IT** (Validation Error).
    *   Exists `_config_version`? -> **DELETE IT**.
    *   Is `telegram.enabled` true? -> **CHECK TOKEN** or **set to `false`**.
3.  **Restore from Golden Backup**:
    *   Path: `backup_2026-02-10_Golden_State/GOLDEN_CONFIG.md`
    *   Action: Copy the file contents back to the root directory and push.
