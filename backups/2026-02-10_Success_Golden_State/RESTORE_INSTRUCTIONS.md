# 🆘 紧急救援手册 / Emergency Restore Guide

## 版本信息 (Version Info)
- **Date**: 2026-02-10
- **Status**: ✅ Verified Stable (Gateway Starts, UI Accessible)
- **Key Features**:
  - `openclaw.zeabur.json`: No Browser, No Telegram, Clean Config.
  - `docker-entrypoint.sh`: Includes **Force Config Reset** (rm command) to clear corrupted volumes.

## 如何恢复 (How to Restore)

如果未来的修改导致 OpenClaw 再次崩溃 (502/Crash)，请执行以下命令瞬间恢复到此版本：

### 方法 1：使用终端 (Terminal)
在项目根目录下运行：

```bash
# 1. 覆盖当前文件
cp backups/2026-02-10_Success_Golden_State/* .

# 2. 提交更改
git add .
git commit -m "Emergency Restore: Revert to 2026-02-10 Golden State"
git push
```

### 方法 2：手动复制 (Manual)
手动将 `backups/2026-02-10_Success_Golden_State/` 目录下的这三个文件复制到项目根目录，覆盖原有文件即可。

---
**Safe to Redeploy immediately after restore.**
