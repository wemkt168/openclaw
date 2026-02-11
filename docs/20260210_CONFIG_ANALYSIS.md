# OpenClaw 配置深度解析 (Configuration Analysis)

本文档整合了针对 2026-02-10 成功版本的 **配置比对报告** 和 **JSON 结构说明**。

---

## 第一部分：配置交叉比对报告 (Comparison Report)

| 特性 | 当前版本 (Golden State) | 官方推荐 (Official) | 差异分析 |
| :--- | :--- | :--- | :--- |
| **持久化机制** | **Code-Driven (Git为主)** | Volume-Driven (硬盘为主) | **核心差异**。为了适应 Zeabur 部署，只要 Git 代码变了，启动时就会**强力重置**硬盘里的旧配置。这确保了部署的确定性。 |
| **浏览器工具** | **Dockerfile 显式安装** | 脚本动态安装 | **更稳健**。由于国内网络和容器环境限制，显式 `RUN npm install playwirght` 更靠谱。JSON 中移除了 `tools.browser` 键以避免校验错误。 |
| **容错策略** | **Telegram 默认关闭** | 默认开启 | **更安全**。Telegram Token 错误会导致服务无限重启。我们默认关闭它，保证服务能先活下来，再在 UI 里手动开启。 |

---

## 第二部分：JSON 配置文件中文详解

以下对应 `openclaw.zeabur.json`：

### 1. 智能体 (Agents)
*   **models**: 定义了 Gemini Flash (主力) 和 Claude Sonnet (备用)。注意：**千万不要加 `contextWindow` 参数**，OpenClaw 新版不再支持在 JSON 里写这个，写了就报错。
*   **sandbox**: `mode: "off"`。这意味着 AI 可以直接在容器里运行 `python` 或 `bash`，权限很大，非常适合开发者自用。

### 2. 网关 (Gateway)
*   **bind**: `"lan"`。绑定局域网端口，允许 Zeabur 转发流量。
*   **controlUi**: `allowInsecureAuth: true`。这允许我们在没有 HTTPS 的测试域名下也能登录后台。

### 3. 工具 (Tools)
*   **elevated**: **提权工具**。我们配置了 `allowFrom: web: ["*"]`。
    *   **官方默认**: Web 端用户不能运行代码。
    *   **我们的修改**: 允许 Web 端用户运行代码。这意味着你在网页版聊天框里让它写 Python，它就能直接跑。

### 4. 杂项
*   **_config_version**: **已移除**。在此版本中，这个键被识别为非法键，必须删除。

---

## 总结
这份配置是针对 **"单人开发者 + Zeabur PaaS 部署"** 场景的最优解。它牺牲了一点点标准性（比如持久化），换取了极高的稳定性和可维护性。
