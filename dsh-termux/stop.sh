#!/data/data/com.termux/files/usr/bin/bash
# DeepSeek Harness · 停止
set -uo pipefail

DSH_HOME_DIR="${DSH_HOME:-$HOME/.dsh}"
PID_FILE="$DSH_HOME_DIR/dsh.pid"

if [ ! -f "$PID_FILE" ]; then
  echo "未找到 PID 文件（可能未用 start.sh 启动）。"
  echo "手动查找进程: pkill -f 'dsh web' 或 pkill -f 'dsh --profile web'"
  exit 0
fi

PID="$(cat "$PID_FILE")"
if kill -0 "$PID" 2>/dev/null; then
  kill "$PID"
  echo "已发送停止信号 (PID $PID)。"
  for _ in 1 2 3 4 5; do
    kill -0 "$PID" 2>/dev/null || break
    sleep 1
  done
  kill -0 "$PID" 2>/dev/null && { echo "仍在运行，强制停止..."; kill -9 "$PID"; }
  echo "✅ 已停止。"
else
  echo "进程 $PID 已不在运行。"
fi
rm -f "$PID_FILE"
