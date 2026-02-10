# OpenClaw 配置文件中文详解 (CONFIG_GUIDE_CN)

此文件是对 `openclaw.zeabur.json` 的中文对照说明。
由于 JSON 文件不支持注释，请参考本文档理解各配置项的含义。

---

## 根结构 (Root)

```json
{
    "env": { ... },     // 环境变量映射
    "agents": { ... },  // 智能体(Agent)核心配置
    "gateway": { ... }, // 网关(Gateway)网络与认证配置
    "channels": { ... },// 聊天渠道(Telegram, Slack等)
    "tools": { ... },   // 工具集(Browser, Web Search等)
    "commands": { ... },// 系统命令权限
    "logging": { ... }  // 日志级别
}
```

## 1. 智能体配置 (agents)

```json
"defaults": {
    "models": {
        // 模型定义: 这里只定义别名(alias)，不要加 contextWindow/maxTokens 等参数以免报错
        "openrouter/anthropic/claude-sonnet-4": { "alias": "sonnet" },
        "openrouter/google/gemini-2.0-flash-001": { "alias": "flash" }
    },
    "model": {
        "primary": "...",  // 主力模型 (Gemini Flash)
        "fallbacks": [...] // 备用模型 (当主力挂了时自动切换)
    },
    "sandbox": {
        "mode": "off" // 沙箱模式: off 表示直接在容器内运行代码(功能最强)
    },
    "thinkingDefault": "low", // 思考深度
    "elevatedDefault": "on"   // 默认开启提权(允许执行代码)
}
```

## 2. 网关配置 (gateway)

```json
"gateway": {
    "bind": "lan",  // 绑定地址: 局域网模式
    "port": 8080,   // 监听端口: Zeabur 默认端口
    "trustedProxies": [ ... ], // 信任的代理IP (Zeabur 内部网络)
    "controlUi": {
        "allowInsecureAuth": true // 允许非HTTPS环境下的认证 (防止配对死循环)
    },
    "auth": {
        "mode": "token", // 认证模式: Token
        "token": "${OPENCLAW_GATEWAY_TOKEN}" // 定义Token的环境变量
    }
}
```

## 3. 渠道配置 (channels)

**注意**: 当前版本我们将 Telegram 禁用了，以防止崩溃。

```json
"telegram": {
    "enabled": false // ❌ 已禁用。如需启用改为 true 并配置 botToken
}
```

## 4. 工具配置 (tools)

```json
"tools": {
    "profile": "full", // 启用全量工具画像
    "elevated": {
        "enabled": true, // 启用提权工具 (Exec, Bash)
        "allowFrom": {   // 允许谁使用?
            "telegram": ["*"], // 所有 Telegram 用户
            "web": ["*"]       // 所有 Web 用户 (这很重要，否则网页版无法运行代码)
        }
    },
    "web": {
        "search": { "enabled": true ... }, // 联网搜索
        "fetch": { "enabled": true }       // 网页抓取
        // 注意: browser (浏览器) 配置已移除，由 Docker 层面支持
    }
}
```
