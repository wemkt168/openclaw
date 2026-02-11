# OpenClaw 快速复原手册 - 10分钟极速版 (10-Minute Rapid Restore SOP)

**⚠️ 目的**: 在任何新环境（Zeabur等）中，使用经过验证的配置（2026-02-10 Golden State）快速部署 OpenClaw。

## 准备步骤 (Prerequisites)

1.  **Zeabur 账号**: 已准备好项目。
2.  **API Keys**: 准备好 `OPENROUTER_API_KEY`, `OPENCLAW_GATEWAY_TOKEN`, `BRAVE_SEARCH_API_KEY`。

---

## 部署流程 (Deployment Flow)

### 1. 恢复文件 (Restore Files)
从此备份文件夹获取以下三个文件，覆盖到代码仓库根目录：
*   `Dockerfile`
*   `docker-entrypoint.sh`
*   `openclaw.zeabur.json`

(如果找不到文件，请直接复制 `GOLDEN_CONFIG.md` 中的代码块)

### 2. 检查关键配置 (Verify Key Configs)
打开 `openclaw.zeabur.json`，确保：
*   ❌ **没有** `tools.browser` 字段 (否则会报错)
*   ❌ **没有** `_config_version` 字段 (否则会报错)
*   ❌ **没有** `contextWindow`/`maxTokens` (否则会报错)
*   ✅ `telegram.enabled` 设为 `false` (防止崩溃)

### 3. 推送代码 (Push Code)
```bash
git add .
git commit -m "Deploy: Restoring Golden State Config"
git push
```

### 4. 设置环境变量 (Zeabur Variables)
在 Zeabur Dashboard -> Variables 中设置：
*   `OPENROUTER_API_KEY`: `sk-or-v1-...`
*   `OPENCLAW_GATEWAY_TOKEN`: `MySecretToken123`
*   `BRAVE_SEARCH_API_KEY`: `...` (可选)
*   `TELEGRAM_BOT_TOKEN`: (可选，即便设置了也不会被使用，除非你手动修改 JSON 开启)

### 5. 等待部署 (Wait for Deployment)
*   **构建时间**: 约 2-3 分钟
*   **启动时间**: 约 1-2 分钟
*   **成功标志**: 日志中出现 `Gateway is HEALTHY and READY!`

---

## 常见问题自救 (Troubleshooting)

| 现象 | 原因 | 解决方案 |
| :--- | :--- | :--- |
| **502 Bad Gateway** | 配置文件没生效，Zeabur 读取了旧 Volume | **不要慌**。当前的 `docker-entrypoint.sh` 会在启动时自动执行 `rm` 命令删除旧配置。**重启一次服务**即可生效。 |
| **UI 打不开** | Token 没设置对 | 检查 `OPENCLAW_GATEWAY_TOKEN` 是否与你 URL 里的 `?token=...` 一致。 |
| **对话没反应** | API Key 问题 | 检查 `OPENROUTER_API_KEY` 是否以 `sk-or-` 开头，且余额充足。 |

**牢记**: 只要这三个文件是 Golden State 版本，系统就一定能跑起来。相信 Git，不要手动改容器文件。
