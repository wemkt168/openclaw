# OpenClaw 配置交叉比对报告 (Configuration Comparison Report)
**版本**: 2026-02-10 Success Golden State
**比对对象**: 官方文档 (docs.openclaw.ai) & 社区最佳实践 (Community Best Practices)

## 1. 持久化与配置更新 (Persistence & Updates)

| 特性 | 当前版本 (Golden State) | 官方推荐 (Official) | 差异分析 |
| :--- | :--- | :--- | :--- |
| **配置来源** | **Git 仓库为准** (Code-Driven) | 容器内持久化文件 (Volume-Driven) | **重大差异 (优势)** |
| **更新机制** | 启动时**强制重置** (`rm` + `cp`) | 手动修改或依赖 Volume 保持 | 官方模式下，Dockerfile 的修改不会覆盖旧 Volume，导致配置更新不生效 (本次事故根源)。<br>当前版本的"强力重置"更适合 Zeabur 这类 PaaS，确保 Git 代码即真理。 |
| **数据安全** | 仅配置重置，Workspace 保留 | 全部持久化 | 合理。我们只重置了 `openclaw.json` 配置文件，聊天记录和 Workspace 数据不受影响。 |

## 2. 浏览器工具 (Browser Tool)

| 特性 | 当前版本 (Golden State) | 官方推荐 (Official) | 差异分析 |
| :--- | :--- | :--- | :--- |
| **启用方式** | **手动安装依赖** (Dockerfile) | 镜像内置或自动安装 | **当前更稳**。官方自动脚本在 Zeabur 这种无头环境(Headless)容易缺依赖。我们在 Dockerfile 里明确写了 `playwright install-deps`。 |
| **配置项** | **已移除** (`tools.browser`) | 需配置 `tools.browser` | **当前更安全**。早前的 `tools.browser` 键导致了 "Unrecognized key" 报错。目前通过 Docker 层面支持，不在 JSON 里硬编码复杂配置，避免了 Schema 校验失败。 |

## 3. Telegram 集成

| 特性 | 当前版本 (Golden State) | 官方推荐 (Official) | 差异分析 |
| :--- | :--- | :--- | :--- |
| **默认状态** | **禁用** (`enabled: false`) | 启用 | **安全策略**。官方默认启用若 Token 无效会无限重启 (Crash Loop)。当前版本禁用是为了防止 401 错误导致整个服务挂掉，需用时可在 UI 手动开启。 |
| **容错性** | 高 (Token 错也能启动) | 低 (Token 错导致 Crash) | 我们的修改提高了系统的鲁棒性。 |

## 4. 权限控制 (Permissions)

| 特性 | 当前版本 (Golden State) | 官方推荐 (Official) | 差异分析 |
| :--- | :--- | :--- | :--- |
| **Elevated** | **Web [*] + TG [*]** | 默认较严格 | **更适合单人使用**。官方默认权限较死，导致 Web UI 无法执行命令。我们开放了 `allowFrom: web: ["*"]`，让您在网页端也能用 Python/Bash，体验更好。 |

## 5. 结论与建议

**总体评价**:
当前版本针对 Zeabur 平台特性和单人开发者场景进行了**深度魔改优化**。它牺牲了一部分"标准 Docker 行为" (如配置持久化)，换取了**"部署即更新"的高确定性**。

**优于官方的地方**:
1.  **GitOps 友好**: 修改代码推送，配置必定生效，不会被旧 Volume 缓存坑害。
2.  **故障隔离**: Telegram 坏了不影响主服务启动。
3.  **依赖明确**: Dockerfile 显式安装浏览器依赖，比隐式自动脚本更可靠。

**潜在风险 (需注意)**:
*   因为每次启动都重置 `openclaw.json`，如果您在 **Web UI (网页设置)** 里修改了模型参数，**重启容器后会丢失**。
*   **建议**: 所有的配置修改（如换模型、改 Token），请务必在 **Git 代码 (`openclaw.zeabur.json`)** 里改，不要在网页里改。

此版本配置逻辑自洽，特别适合目前的调试阶段，**建议保持现状，不再回退到"官方标准模式"。**
