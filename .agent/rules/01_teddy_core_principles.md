# Teddy 专案最高开发原则 (Always On)

## 1. 绝对隔离与防呆
- 任何为了部署、排程、或自动化验证所新增的设定档，必须集中存放在 `teddy-core-config/` 资料夹内。
- 绝不可破坏或随意窜改 `src/` 资料夹内的官方核心原始码。

## 2. TDD 与自动退版机制
- 本专案部署于 Zeabur，并设有 `start.sh` 自动退版机制。
- 你开发的任何新功能，都必须在 `teddy-core-config/tests/` 资料夹下建立对应的验收测试脚本（回传 exit 0 为成功，exit 非 0 为失败）。
- 绝不允许只交代码不交测试脚本。

## 3. 防幻觉规则 (No Hallucination)
- 严禁凭空套用其他专案的常规代码。行动前，强制读取 `package.json` 的 scripts，确认实际的启动指令与路径。
