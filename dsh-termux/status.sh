#!/data/data/com.termux/files/usr/bin/bash
# DeepSeek Harness · 状态查看
set -uo pipefail

DSH_HOME_DIR="${DSH_HOME:-$HOME/.dsh}"
PID_FILE="$DSH_HOME_DIR/dsh.pid"
PORT="${DSH_PORT:-3080}"

echo "── dsh 进程 ──"
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "状态: ✅ 运行中 (PID $(cat "$PID_FILE"))"
else
  echo "状态: ⛔ 未运行"
fi

echo "── 相关进程 ──"
pgrep -af 'dsh (web|--profile web)' 2>/dev/null || echo "（无）"

echo "── 端口监听 ──"
ss -ltnp 2>/dev/null | grep ":$PORT" || echo "（未监听 127.0.0.1:$PORT）"

echo "── 最近日志 ──"
if [ -f "$DSH_HOME_DIR/dsh.log" ]; then
  tail -n 15 "$DSH_HOME_DIR/dsh.log"
else
  echo "（无日志文件）"
fi
