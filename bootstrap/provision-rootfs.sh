#!/usr/bin/env bash
# 方案 B 进阶 · 真·预置 rootfs：把 Node + DSH 烤进 Termux bootstrap
#
# 目标：让 bootstrap-aarch64.zip 里直接含 nodejs-lts + @deepseek-ai/dsh，
#       首启离线可用（不需要首启联网装机）。
#
# 用法（两种）：
#   A) 在 termux-packages 的构建流程里调用：
#        ./scripts/generate-bootstraps.sh 生成 rootfs 后，把本脚本作为
#        "后置 hook" 传入 rootfs 路径执行。
#   B) 手动对已有 bootstrap rootfs 目录执行：
#        sudo bash provision-rootfs.sh /path/to/bootstrap-rootfs
#
# 前置：本脚本需要在能 chroot/proot 进入 aarch64 rootfs 的环境里跑
#       （x86 主机需 qemu-user-static + binfmt；或直接在 aarch64 设备上跑）。
set -euo pipefail

ROOTFS="${1:?用法: provision-rootfs.sh <bootstrap-rootfs-dir>}"
ROOTFS="$(cd "$ROOTFS" && pwd)"
[ -d "$ROOTFS/data/data/com.termux/files/usr" ] || {
  echo "❌ 目录不像 Termux bootstrap（缺 data/data/com.termux/files/usr）: $ROOTFS" >&2
  exit 1
}

USR="$ROOTFS/data/data/com.termux/files/usr"
HOME_DIR="$ROOTFS/data/data/com.termux/files/home"
PROVISION_SCRIPT="$ROOTFS/provision-dsh.sh"

# ── 在 rootfs 内部执行的装机脚本（落地成文件，供 chroot/proot 调用）────────
cat > "$PROVISION_SCRIPT" <<'INNER'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
export PATH=/data/data/com.termux/files/usr/bin:$PATH
echo "==> [rootfs] pkg update + 安装工具链"
pkg update -y
pkg install -y nodejs-lts git build-essential python binutils clang make tmux openssh
echo "==> [rootfs] 全局安装 @deepseek-ai/dsh"
npm install -g @deepseek-ai/dsh
mkdir -p "$HOME/.dsh"
echo "==> [rootfs] DSH 预置完成: $(command -v dsh)"
INNER
chmod +x "$PROVISION_SCRIPT"

# ── 进入 rootfs 执行 ──────────────────────────────────────────────────────
echo "==> 进入 rootfs 执行预置（可能需要 root / proot / qemu）"
if [ "$(id -u)" -eq 0 ] && command -v chroot >/dev/null 2>&1; then
  # 优先 chroot；Termux 的 bash 是静态/自包含的，chroot 通常可行
  chroot "$ROOTFS" /data/data/com.termux/files/usr/bin/bash /provision-dsh.sh
elif command -v proot >/dev/null 2>&1; then
  proot -r "$ROOTFS" -b /dev -b /proc -b /sys /data/data/com.termux/files/usr/bin/bash /provision-dsh.sh
else
  echo "❌ 需要 root+chroot 或 proot 才能进入 rootfs；请手动执行：" >&2
  echo "    chroot $ROOTFS /data/data/com.termux/files/usr/bin/bash /provision-dsh.sh" >&2
  exit 1
fi

rm -f "$PROVISION_SCRIPT"
echo "✅ rootfs 预置完成。现在把 $ROOTFS 打包成 bootstrap-aarch64.zip 供 termux-app 使用。"
