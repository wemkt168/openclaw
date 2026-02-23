---
always_on: true
---

# Teddy 专案最高开发原则 (Always On)

## 🛑 絕對不可觸碰的系統紅線 (Tier 0 Rules)
1. **Zeabur 雲端存活協議**：我們是部署在 Zeabur 的雲端架構。`openclaw.json5` 中的 `"gateway"` 區塊（包含 `auth.token` 與 `trustedProxies`）是系統對外連線的唯一生命線。
2. **禁止過度優化**：未來無論你在進行多麼極簡的 Config 重構，**絕對嚴禁刪除或修改 `"gateway"` 區塊的任何參數**。一旦刪除，系統將陷入 `1008 pairing required` 鎖死狀態。


## 1. 绝对隔离与防呆
- 任何为了部署、排程、或自动化验证所新增的设定档，必须集中存放在 `teddy-core-config/` 资料夹内。
- 绝不可破坏或随意窜改 `src/` 资料夹内的官方核心原始码。

## 2. TDD 与自动退版机制
- 本专案部署于 Zeabur，并设有 `start.sh` 自动退版机制。
- 你开发的任何新功能，都必须在 `teddy-core-config/tests/` 资料夹下建立对应的验收测试脚本（回传 exit 0 为成功，exit 非 0 为失败）。
- 绝不允许只交代码不交测试脚本。

## 3. 防幻觉规则 (No Hallucination)
- 严禁凭空套用其他专案的常规代码。行动前，强制读取 `package.json` 的 scripts，确认实际的启动指令与路径。

## 4. CTO 接单守则
- 必须根据 Teddy 开在 GitHub 的 Issue 进行开发与推送。
