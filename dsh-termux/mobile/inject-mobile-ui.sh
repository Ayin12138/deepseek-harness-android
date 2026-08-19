#!/data/data/com.termux/files/usr/bin/bash
# 把 mobile.css 注入到 DSH Web 前端（幂等，可重复执行）
# 原理：DSH 的静态服务器会原样服务 dist 目录下的文件，
#       并在 index.html 的 <head> 里加载我们追加的 /mobile.css。
set -euo pipefail

CSS_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/mobile.css"
[ -f "$CSS_SRC" ] || { echo "❌ 找不到 $CSS_SRC" >&2; exit 1; }

# 定位全局安装的前端 dist 目录（Termux 全局 node_modules）
DIST_INDEX="$(find "${PREFIX}/lib/node_modules" -path '*/@deepseek-ai/dsh-web-frontend/dist/index.html' 2>/dev/null | head -n1)"

# 兜底：npm root -g
if [ -z "$DIST_INDEX" ]; then
  NPM_ROOT="$(npm root -g 2>/dev/null || true)"
  DIST_INDEX="$(find "$NPM_ROOT" -path '*/@deepseek-ai/dsh-web-frontend/dist/index.html' 2>/dev/null | head -n1)"
fi

if [ -z "$DIST_INDEX" ]; then
  echo "❌ 未找到 @deepseek-ai/dsh-web-frontend/dist/index.html" >&2
  echo "   请先执行 install.sh 完成 DSH 安装。" >&2
  exit 1
fi

DIST_DIR="$(dirname "$DIST_INDEX")"
echo "==> 前端目录: $DIST_DIR"

# 1) 拷贝 mobile.css 到 dist 目录
cp "$CSS_SRC" "$DIST_DIR/mobile.css"
chmod 644 "$DIST_DIR/mobile.css"

# 2) 幂等注入 <link>（已注入则跳过）
LINK_TAG='<link rel="stylesheet" href="/mobile.css" />'
if grep -qF "$LINK_TAG" "$DIST_INDEX"; then
  echo "    index.html 已注入，跳过。"
else
  sed -i "s|</head>|    ${LINK_TAG}\n  </head>|" "$DIST_INDEX"
  echo "    ✅ 已注入 mobile.css 引用。"
fi

echo "✅ 完成。刷新浏览器（或 Ctrl+F5）即可看到移动端优化效果。"
