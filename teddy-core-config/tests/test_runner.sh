#!/bin/bash
# 找出 tests 資料夾下最新的測試檔
LATEST_TEST=$(ls -t ./teddy-core-config/tests/test_*.sh 2>/dev/null | grep -v "test_runner.sh" | head -n 1)

if [ -z "$LATEST_TEST" ]; then
    echo "沒有找到新的測試檔，跳過測試。"
    exit 0
fi

echo "執行最新測試: $LATEST_TEST"
bash "$LATEST_TEST"
exit $?
