---
name: github_issue_creator
description: "Automatically creates a timestamped GitHub issue in the wemkt168/openclaw repository when Teddy needs human assistance, a new tool, or permission updates."
---

# GitHub Issue Creator

当你 (Teddy) 遇到错误、缺少工具或需要代码修改时，可使用此工具自动创建 GitHub Issue。

## 核心功能

- **自动时间戳**: 标题自动添加 `[YYYYMMDD]` 或 `[YYYYMMDD-N]` 前缀
- **自动标签**: 所有 Issue 自动附加 `teddy-auto` 标签
- **重复检测**: 发包前先搜索同标题 Issue，避免重复创建
- **退避重试**: 网络失败自动重试最多 3 次（指数退避）
- **本地草稿**: 同步在 `teddy-core-config/issue_drafts/` 保留 Markdown 草稿

## 使用方式

```bash
node ./teddy-core-config/skills/github_issue_creator/create_issue.mjs "问题简述" "详细说明"
```

## 环境变量

| 变量 | 必填 | 说明 |
|------|------|------|
| `GITHUB_TOKEN` | ✅ | GitHub Personal Access Token |
| `GITHUB_REPO` | ❌ | 目标仓库 (默认: `wemkt168/openclaw`) |
| `DRY_RUN` | ❌ | 设为 `1` 跳过 API 调用（仅写本地草稿） |

## 注意事项

- 脚本自动处理时间戳，**不要**手动在标题中添加日期
- 第一个参数为简短标题，第二个参数为详细正文
- 若检测到重复 Issue，脚本会跳过创建并输出已有 Issue 的链接
