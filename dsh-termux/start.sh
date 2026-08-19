#!/data/data/com.termux/files/usr/bin/bash
# DeepSeek Harness · 后台启动
# 用法: bash start.sh
set -euo pipefail

DSH_HOME_DIR="${DSH_HOME:-$HOME/.dsh}"
PORT="${DSH_PORT:-3080}"
PID_FILE="$DSH_HOME_DIR/dsh.pid"
LOG_FILE="$DSH_HOME_DIR/dsh.log"
mkdir -p "$DSH_HOME_DIR"

# 加载回退层环境变量（端点、端口等；密钥库由 DSH 自行读取）
[ -f "$DSH_HOME_DIR/.env" ] && set -a && . "$DSH_HOME_DIR/.env" && set +a

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "⚠️  dsh 已在运行 (PID $(cat "$PID_FILE"))。用 bash stop.sh 停止后重试。"
  exit 0
fi

echo "==> 启动 dsh web (127.0.0.1:$PORT)，日志: $LOG_FILE"
nohup dsh web --port "$PORT" >> "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"

sleep 2
if kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "✅ 已启动 (PID $(cat "$PID_FILE"))。"
  echo "   手机浏览器打开: http://127.0.0.1:$PORT"
else
  echo "❌ 启动失败，查看日志:" >&2
  tail -n 30 "$LOG_FILE" >&2 || true
  rm -f "$PID_FILE"
  exit 1
fi
