#!/data/data/com.termux/files/usr/bin/bash
# Termux:Boot 开机自启脚本（复制到 ~/.termux/boot/dsh.sh）
# 开机后由 Termux:Boot 以 $HOME 为工作目录执行，自动拉起 dsh web。
set -uo pipefail

DSH_HOME_DIR="${DSH_HOME:-$HOME/.dsh}"
PORT="${DSH_PORT:-3080}"
LOG_FILE="$DSH_HOME_DIR/dsh.log"
PID_FILE="$DSH_HOME_DIR/dsh.pid"
mkdir -p "$DSH_HOME_DIR"

# 加载回退层环境变量
[ -f "$DSH_HOME_DIR/.env" ] && set -a && . "$DSH_HOME_DIR/.env" && set +a

# 已在运行则跳过
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  exit 0
fi

# 等待网络就绪（最多 30s），避免开机过早启动
for _ in $(seq 1 15); do
  ping -c1 -W2 1.1.1.1 >/dev/null 2>&1 && break
  sleep 2
done

nohup dsh web --port "$PORT" >> "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"
