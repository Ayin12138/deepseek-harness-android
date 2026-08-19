# 方案 B 进阶 · 真·预置 rootfs（首启离线可用）

`apk/` 里的是「首启自动装机」：APK 首启联网跑 `first-boot.sh` 装 DSH。
本目录做更进一步：**把 Node + DSH 直接烤进 Termux 的 bootstrap rootfs**，
首启即含，不依赖首启联网。

## 代价

- 需要重建 termux-packages 的 bootstrap（Docker + qemu-user-static，aarch64），
  构建很重（数十分钟到数小时）。
- 每次 DSH 升级都要重建 bootstrap 并重新发版 APK。

## 完整流程

1. 克隆并构建 termux-packages 的 bootstrap：

```bash
git clone https://github.com/termux/termux-packages
cd termux-packages
# 官方生成 bootstrap 的脚本（内部用 Docker + qemu 构建 aarch64 rootfs）
./scripts/generate-bootstraps.sh
```

2. 拿到生成的 rootfs 目录后，用 [`provision-rootfs.sh`](provision-rootfs.sh) 预置 DSH：

```bash
sudo bash provision-rootfs.sh <生成的 bootstrap rootfs 目录>
# 或对已解包的 bootstrap-aarch64.zip 目录执行
```

3. 重新打包成 `bootstrap-aarch64.zip`（保持 termux-app 期望的目录结构：
   `data/data/com.termux/files/...`）。

4. 让 termux-app 用你的 bootstrap：

```java
// termux-app 源码里的 bootstrap 下载 URL 常量（版本不同位置不同，以当前源码为准）
public static final String TERMUX_BOOTSTRAP_URL = "https://你的域名/bootstrap-aarch64.zip";
```

   - 方式一：挂到自建 HTTPS 地址（务必 HTTPS + 保留 SHA256 校验）。
   - 方式二：把 zip 放进 `app/src/main/assets/`，改 bootstrap 加载逻辑走 asset。

5. 编译 APK（本地或 GitHub Actions，见 `../.github/workflows/build-apk.yml`）。

## 安全

- 预置的 rootfs 里**只放 DSH 程序本身**，不放任何 `DEEPSEEK_API_KEY` / token。
- 密钥仍由最终用户首启后在 Web UI / `configure.sh` 里填。
