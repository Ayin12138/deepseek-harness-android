#!/data/data/com.termux/files/usr/bin/bash
# DeepSeek Harness · Termux 一键装机脚本
# 用法: bash install.sh
set -euo pipefail

# 仅在 Termux 环境执行（有 pkg 且存在 $PREFIX）
if ! command -v pkg >/dev/null 2>&1 || [ -z "${PREFIX:-}" ]; then
  echo "❌ 请在 Termux 里运行本脚本（需要 pkg 与 \$PREFIX）。" >&2
  exit 1
fi

echo "==> [1/5] 更新软件源"
pkg update -y

echo "==> [2/5] 安装基础工具链（Node 22 LTS + 编译环境）"
pkg install -y \
  nodejs-lts \
  git \
  build-essential \
  python \
  binutils \
  clang \
  make \
  tmux \
  openssh \
  termux-services

# 确认 Node 版本 >= 22（DSH 依赖 node:sqlite，22 起内置）
NODE_MAJOR="$(node -v | sed 's/^v//' | cut -d. -f1)"
if [ "${NODE_MAJOR}" -lt 22 ]; then
  echo "❌ 需要 Node >= 22，当前 $(node -v)。请先: pkg install -y nodejs-lts" >&2
  exit 1
fi
echo "    Node $(node -v), npm $(npm -v)"

echo "==> [3/5] 全局安装 @deepseek-ai/dsh（首次会编译原生模块 node-pty，耗时较长）"
npm install -g @deepseek-ai/dsh

if ! command -v dsh >/dev/null 2>&1; then
  # npm 全局 bin 路径兜底
  export PATH="$PREFIX/bin:$PATH"
  if ! command -v dsh >/dev/null 2>&1; then
    echo "❌ 安装完成但找不到 dsh 命令，请检查 npm 全局 bin 是否在 PATH。" >&2
    exit 1
  fi
fi
echo "    dsh -> $(command -v dsh)"

echo "==> [4/5] 初始化配置目录 ~/.dsh"
DSH_HOME_DIR="${DSH_HOME:-$HOME/.dsh}"
mkdir -p "$DSH_HOME_DIR" "$HOME/.termux/boot"

# .env 模板（回退层，configure.sh 会写主密钥库 .credentials.yaml）
if [ ! -f "$DSH_HOME_DIR/.env" ] && [ -f "$(dirname "$0")/env/dsh.env.example" ]; then
  cp "$(dirname "$0")/env/dsh.env.example" "$DSH_HOME_DIR/.env"
  chmod 600 "$DSH_HOME_DIR/.env"
  echo "    已创建 $DSH_HOME_DIR/.env（模板）"
fi

# termux-services 服务目录 + boot 脚本
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$PREFIX/var/service/dsh"
if [ -f "$SELF_DIR/services/dsh/run" ]; then
  cp "$SELF_DIR/services/dsh/run" "$PREFIX/var/service/dsh/run"
  chmod +x "$PREFIX/var/service/dsh/run"
fi
if [ -f "$SELF_DIR/boot/dsh.sh" ]; then
  cp "$SELF_DIR/boot/dsh.sh" "$HOME/.termux/boot/dsh.sh"
  chmod +x "$HOME/.termux/boot/dsh.sh"
fi

echo "==> [5/5] 注入移动端 UI"
if [ -f "$SELF_DIR/mobile/inject-mobile-ui.sh" ]; then
  bash "$SELF_DIR/mobile/inject-mobile-ui.sh" || echo "    （移动端 UI 注入跳过，可稍后手动执行）"
fi

echo
echo "✅ 安装完成。接下来："
echo "   1) bash configure.sh   # 配置 DEEPSEEK_API_KEY / 模型 / 端口"
echo "   2) bash start.sh       # 启动"
echo "   3) 浏览器打开 http://127.0.0.1:3080"
echo
echo "   开机自启: sv-enable dsh  （需先重开一次 Termux 使 services 生效）"
