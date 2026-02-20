#!/bin/bash
echo "🚀 Teddy 系統啟動中..."
echo "🔍 開始執行功能驗收測試..."

# 呼叫專屬資料夾內的測試調度員
bash ./teddy-core-config/tests/test_runner.sh
TEST_RESULT=$?

if [ $TEST_RESULT -eq 0 ]; then
    echo "🟢 測試通過！Teddy 功能正常上線。"
    # 啟動 OpenClaw 主程式 (在專案根目錄執行)
    pnpm start gateway --allow-unconfigured --bind lan --port ${PORT:-8080}
else
    echo "🔴 測試失敗！檢測到致命錯誤！"
    echo "🔄 正在啟動自動退版機制 (Rollback)..."
    
    # 設定 GitHub 身份
    git config --global user.name "Teddy-QA-Bot"
    git config --global user.email "teddy@openclaw.local"
    git remote set-url origin https://x-access-token:${GITHUB_TOKEN}@github.com/wemkt168/openclaw.git
    
    # 強制退回上一個正常的 Commit 並推送到 GitHub
    git revert --no-edit HEAD
    git push origin main
    
    echo "退版指令已發送，等待 Zeabur 重新部署舊版..."
    sleep 300 
fi
