# 🤖 Agent 协作交接手册 (Agent Handoff Manual)

**最后更新**: 2026-02-11 (Battle-Tested Version)
**目标读者**: 接手项目的 AI Agent (Gemini, Claude, DeepSeek 等) 及开发者
**项目环境**: OpenClaw 部署于 Zeabur (PaaS)

此文档旨在帮助后续的 Agent 快速理解本项目特殊的部署环境与环境变量配置，防止因环境差异导致服务崩溃。

---

## 🇨🇳 第一部分：中文版 (Chinese Version)

### 1. 🔑 环境变量与密钥管理 (Secrets & Env Vars)

我们有两个层面的环境变量：
1.  **Zeabur 生产环境**: 在 Zeabur Dashboard 设置。
2.  **本地/备份环境**: 在项目根目录的 `.env.zeabur` 文件中。

#### 📄 本地密钥文件: `.env.zeabur` (重要！)

**致 Agent**: 如果你想找真实的 API Key (比如 `sk-or-...`)，**请直接查看根目录下的 `.env.zeabur` 文件**。不要在硬盘里乱搜了！

| 变量名 (Key) | 用途说明 | 重要性 | 备注 |
| :--- | :--- | :--- | :--- |
| `OPENROUTER_API_KEY` | **模型密钥** | 🔴 **极高** | 真实值见 `.env.zeabur` |
| `OPENCLAW_GATEWAY_TOKEN` | **认证令牌** | 🔴 **极高** | 真实值见 `.env.zeabur` |
| `TELEGRAM_BOT_TOKEN` | **Telegram 机器人密钥** | 🟡 中等 | (已禁用，需在 UI 开启) |
| `BRAVE_SEARCH_API_KEY` | **联网搜索密钥** | 🟡 中等 | 真实值见 `.env.zeabur` |
| `POSTGRES_...` | **数据库连接** | 🟢 系统级 | 真实值见 `.env.zeabur` |
| `S3_...` | **对象存储 (MinIO)** | 🟢 系统级 | 真实值见 `.env.zeabur` |

### 2. 🔥 实战验证的配置陷阱 (Critical Findings)

**致 Agent**: 以下配置是经过多次失败教训总结出来的，**请勿随意更改**。

#### A. 记忆搜索 (Memory Search) - OpenRouter 复用术
*   **问题**: `memory_search` 默认要求 OpenAI 或 Google Key，但我们不想买新 Key。
*   **解决方案**: OpenRouter 的 Embeddings API 兼容 OpenAI 格式。我们通过配置欺骗 OpenClaw：
    ```json
    "memorySearch": {
      "provider": "openai",  // 伪装成 OpenAI
      "remote": {
        "baseUrl": "https://openrouter.ai/api/v1", // 指向 OpenRouter
        "headers": {
          "Authorization": "Bearer ${OPENROUTER_API_KEY}" // 复用现有 Key
        }
      },
      "model": "openai/text-embedding-3-small" // OpenRouter 支持此模型
    }
    ```
*   **验证**: 我们已通过脚本 `test_openrouter_embeddings.mjs` 验证，该模型可用且兼容。

#### B. 网络代理 (Trusted Proxies) - 502/WebSocket 杀手
*   **问题**: Zeabur 部署后，WebSocket 连接（聊天窗口）不断断开，或者是 502 错误。
*   **原因**: Zeabur 基于 Kubernetes (K3s)，其内部 Pod 网段是 `10.42.0.0/16`。如果不信任此网段，Nginx Ingress 转发的连接会被 OpenClaw 视为不安全来源。
*   **必需配置**:
    ```json
    "trustedProxies": [
      "10.0.0.0/8", 
      "172.16.0.0/12", 
      "192.168.0.0/16", 
      "10.42.0.0/16" // <--- 必须有这个！
    ]
    ```

### 3. 🏗️ 架构与文件系统 (特殊机制)

**致未来的 Agent，请仔细阅读以下机制，这与标准 Docker 不同：**

1.  **独有的“强制重置”逻辑 (Force Reset)**:
    *   **问题**: Zeabur 会持久化保留 `/home/node/.openclaw` 目录。如果里面残留了旧的、错误的配置文件，你即使推送了新的 Git 代码，服务读取的还是旧配置，导致部署失败。
    *   **解决方案**: 我们的启动脚本 (`docker-entrypoint.sh`) 写死了逻辑：**每次启动时，强制删除持久化目录里的 `openclaw.json`**。
    *   **你的行动准则**: **Git 代码是唯一真理**。不要试图 SSH 进容器修改文件，也不要指望容器重启后文件还在。**修改 `openclaw.zeabur.json` 并推送到仓库**，才是唯一正确的修改方式。

2.  **容器内关键路径**:
    *   配置文件: `/home/node/.openclaw/openclaw.json` (由启动脚本生成)
    *   聊天记录: `/home/node/.openclaw/workspace` (只有这个目录是真正持久化且安全的)
    *   浏览器文件: `/home/node/.openclaw/playwright` (持久化保留的大文件)

### 4. 🚨 故障救援协议 (Rescue Protocol)

**如果遇到 502 Bad Gateway 或 Crash Loop (无限重启):**

1.  **第一步**: 打开 `.env.zeabur`，确认里面的 Key 是否正确。
2.  **第二步**: 检查 **Zeabur 变量** 是否漏填了这些 Key。
3.  **第三步**: 检查配置文件 (`openclaw.zeabur.json`) 是否有非法字段 (如 `tools.browser`, `_config_version`)。
4.  **第四步 (核弹级)**: 使用"黄金备份"恢复:
    *   路径: `docs/20260210_GOLDEN_CONFIG.md` (请寻找最新的 GOLDEN_CONFIG)
    *   操作: 将该文件中的代码完整覆盖回根目录，提交推送。

---
---

## 🇺🇸 Part 2: English Version

### 1. 🔑 Environment Variables & Secrets

We manage secrets in two places:
1.  **Production (Zeabur)**: Configured in the Dashboard.
2.  **Local/Backup**: Stored in `.env.zeabur`.

#### 📄 Local Secrets File: `.env.zeabur` (IMPORTANT!)

**To Agent**: If you are looking for the ACTUAL API Keys (e.g., `sk-or-...`), **LOOK AT `.env.zeabur` in the root directory**. Do not scan the entire hard drive!

(See Chinese section for table)

### 2. 🔥 Battle-Tested Critical Findings (DO NOT CHANGE)

#### A. Memory Search - The OpenRouter Trick
*   **Problem**: Cannot afford separate OpenAI keys for embedding.
*   **Solution**: Use OpenRouter's OpenAI-compatible endpoint.
*   **Config**: Set `provider: "openai"` but point `baseUrl` to `https://openrouter.ai/api/v1` and reuse `OPENROUTER_API_KEY`. This is verified to work.

#### B. Trusted Proxies - The 502 Killer
*   **Problem**: WebSocket connections fail on Zeabur.
*   **Cause**: K3s internal pod CIDR (`10.42.0.0/16`) is untrusted.
*   **Fix**: You MUST add `"10.42.0.0/16"` to `trustedProxies` in `openclaw.zeabur.json`.

(See Section 3 & 4 in Chinese version for Architecture & Rescue Protocol which remain unchanged.)
