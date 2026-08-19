#!/data/data/com.termux/files/usr/bin/bash
# 方案 B · 首次启动自动装机脚本
# 用途：打进 termux-app 的 asset，Termux 首次启动后执行一次，
#       自动装好 Node 工具链 + DeepSeek Harness 并配置移动端 UI。
# 非交互；可选从 /sdcard/dsh.env 读取 DEEPSEEK_API_KEY 等（不强求）。
set -euo pipefail

LOG="$HOME/.dsh/first-boot.log"
mkdir -p "$HOME/.dsh"
exec > >(tee -a "$LOG") 2>&1
echo "==> first-boot: $(date)"

# 1) 等待网络就绪（最多 60s）
for _ in $(seq 1 30); do
  ping -c1 -W2 1.1.1.1 >/dev/null 2>&1 && { echo "    网络就绪"; break; }
  sleep 2
done

# 2) 可选：从 /sdcard/dsh.env 读密钥（若用户提前放了）
if [ -f /sdcard/dsh.env ]; then
  echo "    发现 /sdcard/dsh.env，加载之"
  set -a; . /sdcard/dsh.env; set +a
fi

# 3) 装工具链（Node 22 LTS + 编译环境）
echo "==> 安装工具链"
pkg update -y
pkg install -y nodejs-lts git build-essential python binutils clang make tmux openssh

NODE_MAJOR="$(node -v | sed 's/^v//' | cut -d. -f1)"
[ "${NODE_MAJOR}" -ge 22 ] || { echo "❌ Node < 22"; exit 1; }

# 4) 全局安装 DSH
echo "==> 安装 @deepseek-ai/dsh（首次编译 node-pty，耗时较长）"
npm install -g @deepseek-ai/dsh

# 5) 初始化配置目录
DSH_HOME_DIR="${DSH_HOME:-$HOME/.dsh}"
mkdir -p "$DSH_HOME_DIR"
if [ -f "$HOME/.termux/first-boot-extra/dsh.env.example" ]; then
  cp "$HOME/.termux/first-boot-extra/dsh.env.example" "$DSH_HOME_DIR/.env"
  chmod 600 "$DSH_HOME_DIR/.env"
fi
if [ -n "${DEEPSEEK_API_KEY:-}" ]; then
  printf '# DSH 密钥库\nDEEPSEEK_API_KEY: "%s"\n' "$DEEPSEEK_API_KEY" > "$DSH_HOME_DIR/.credentials.yaml"
  chmod 600 "$DSH_HOME_DIR/.credentials.yaml"
fi

# 6) 注入移动端 UI（若随包附带了 mobile.css）
if [ -f "$HOME/.termux/first-boot-extra/mobile.css" ]; then
  DIST_INDEX="$(find "$PREFIX/lib/node_modules" -path '*/@deepseek-ai/dsh-web-frontend/dist/index.html' 2>/dev/null | head -n1)"
  if [ -n "$DIST_INDEX" ]; then
    cp "$HOME/.termux/first-boot-extra/mobile.css" "$(dirname "$DIST_INDEX")/mobile.css"
    if ! grep -qF '/mobile.css' "$DIST_INDEX"; then
      sed -i 's|</head>|    <link rel="stylesheet" href="/mobile.css" />\n  </head>|' "$DIST_INDEX"
    fi
  fi
fi

echo "==> first-boot 完成"
echo "    浏览器打开 http://127.0.0.1:3080 使用（先跑: dsh web）"
