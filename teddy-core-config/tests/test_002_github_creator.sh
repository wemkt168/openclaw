#!/bin/bash
echo "==> 驗證 github_issue_creator 工具腳本 <=="

TARGET_FILE="./teddy-core-config/skills/github_issue_creator/create_issue.mjs"

if [ ! -f "$TARGET_FILE" ]; then
    echo "🔴 測試失敗: $TARGET_FILE 檔案不存在！"
    exit 1
fi

echo "🟢 檔案存在檢查通過。"

# 使用 node -c 來驗證 JS 語法正確性
node -c "$TARGET_FILE"
if [ $? -ne 0 ]; then
    echo "🔴 測試失敗: $TARGET_FILE 語法不正確！"
    exit 1
fi

echo "🟢 語法檢查通過。"

# 驗證 SKILL.md 是否存在
SKILL_FILE="./teddy-core-config/skills/github_issue_creator/SKILL.md"
if [ ! -f "$SKILL_FILE" ]; then
    echo "🔴 測試失敗: $SKILL_FILE 檔案不存在！"
    exit 1
fi

echo "🟢 SKILL.md 存在檢查通過。"

echo "🟢 測試 test_002_github_creator 全數通過！"
exit 0
