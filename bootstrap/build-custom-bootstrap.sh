#!/usr/bin/env bash
# 一次性构建「自定义包名/前缀」的 Termux bootstrap（方案 B 共存版）
#
# 原理：Termux 的 bootstrap 二进制里硬编码了 /data/data/<包名>/files/usr 前缀。
# 要换包名共存，就必须用新前缀重建一次 bootstrap（只做这一次，之后 DSH 仍 npm 升级）。
#
# 用法:
#   bash build-custom-bootstrap.sh [新包名] [架构]
#   例: bash build-custom-bootstrap.sh com.dsh.termux aarch64
#
# 前置: Docker（含 qemu-user-static，脚本会通过 run-docker.sh 准备）。
# 注意: 构建很重（数小时、需大磁盘/内存），建议在 4 核以上机器或 GitHub Actions 跑。
set -euo pipefail

PKG="${1:-com.dsh.termux}"
ARCH="${2:-aarch64}"              # 手机 arm64-v8a → aarch64
REPO="${TERMUX_PACKAGES_REPO:-https://github.com/termux/termux-packages}"
DIR="${TERMUX_PACKAGES_DIR:-termux-packages}"

echo "==> 包名: $PKG  架构: $ARCH"
[ -d "$DIR" ] || git clone --depth 1 "$REPO" "$DIR"
cd "$DIR"

# 1) 改包名 → 前缀自动变为 /data/data/<PKG>/files/usr
sed -i "s|^TERMUX_APP__PACKAGE_NAME=\"com.termux\"|TERMUX_APP__PACKAGE_NAME=\"$PKG\"|" scripts/properties.sh
grep -nE '^TERMUX_APP__PACKAGE_NAME=' scripts/properties.sh

# 2) 构建 bootstrap（Docker + qemu，耗时数小时；加 --add 可多带包）
./scripts/run-docker.sh ./scripts/build-bootstraps.sh --architectures "$ARCH"

# 3) 产物在 termux-packages 根目录
OUT="bootstrap-${ARCH}.zip"
[ -f "$OUT" ] || { echo "❌ 未找到 $OUT"; exit 1; }
echo "==> 产物: $(pwd)/$OUT"
echo "==> SHA256: $(sha256sum "$OUT" | awk '{print $1}')"
