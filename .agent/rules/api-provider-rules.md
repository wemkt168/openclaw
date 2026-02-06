# 第三方 API 提供商规范 (最高优先级)

> ⚠️ **重要**：用户主要使用第三方 API 提供商（如 OpenRouter、fal.ai），而非原厂直连。所有代码和配置必须遵循以下规范。

> 📌 **注意**：模型 ID 格式**因应用/框架而异**，不是全球统一标准。
> 使用新应用前，务必先查阅该应用的官方文档确认正确格式。
> 以下示例基于 OpenClaw，其他框架可能不同。

---

## 1. 模型 ID 格式规范

**核心规则**：使用第三方 API 提供商时，模型 ID 必须使用 **三段式格式**。

| 场景 | ❌ 错误格式 (两段式) | ✅ 正确格式 (三段式) |
|------|---------------------|---------------------|
| OpenRouter 调用 Claude | `anthropic/claude-sonnet-4` | `openrouter/anthropic/claude-sonnet-4` |
| OpenRouter 调用 GPT | `openai/gpt-4o` | `openrouter/openai/gpt-4o` |
| OpenRouter 调用 Gemini | `google/gemini-2.0-flash` | `openrouter/google/gemini-2.0-flash-001` |
| fal.ai 调用模型 | `flux/schnell` | `fal-ai/flux/schnell` |

---

## 2. API Key 环境变量命名

| 提供商 | 环境变量名 |
|--------|-----------|
| OpenRouter | `OPENROUTER_API_KEY` |
| fal.ai | `FAL_KEY` 或 `FAL_API_KEY` |
| Anthropic (直连) | `ANTHROPIC_API_KEY` |
| OpenAI (直连) | `OPENAI_API_KEY` |

---

## 3. 配置文件检查清单

在编写任何 AI 模型配置时，必须确认：
- [ ] 模型 ID 是否使用了正确的三段式格式？
- [ ] 对应的 API Key 环境变量是否已设置？
- [ ] 如果使用备用模型 (fallback)，是否也使用了三段式格式？

---

## 4. 常见错误案例

```json5
// ❌ 错误 - 会报 "No API key found for provider anthropic"
{
  model: { primary: "anthropic/claude-sonnet-4" }
}

// ✅ 正确 - 使用 OpenRouter 作为中间层
{
  model: { primary: "openrouter/anthropic/claude-sonnet-4" }
}
```

---

## 5. 用户偏好

- **首选 AI 提供商**：OpenRouter (支持多模型切换)
- **首选图像/视频 API**：fal.ai
- **部署平台**：Zeabur
- **消息通道**：Telegram

---

## 6. 为什么需要三段式格式？

当使用两段式格式（如 `anthropic/claude-sonnet-4`）时，系统会：
1. 尝试直接连接 Anthropic API
2. 寻找 `ANTHROPIC_API_KEY` 环境变量
3. 找不到时报错：`No API key found for provider "anthropic"`

使用三段式格式（如 `openrouter/anthropic/claude-sonnet-4`）时，系统会：
1. 识别 `openrouter` 是中间层提供商
2. 寻找 `OPENROUTER_API_KEY` 环境变量
3. 通过 OpenRouter 路由到 Anthropic 的 Claude 模型
