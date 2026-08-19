# 方案 B · 改包名共存（一个桌面装两个 Termux）

官方 Termux 的二进制里硬编码了 `/data/data/com.termux/files/usr` 前缀，所以换包名必须**用新前缀重建一次 bootstrap**（只这一次，之后 DSH 仍 `npm i -g` 升级，永不重编 APK）。

产物：**第二个 Termux**，包名如 `com.dsh.termux`，和官方 `com.termux` 同时装在同一个桌面、互不干扰。

## 需要的三块拼图（都已就绪）

1. **改包名补丁** → [`../apk/termux-app-rename.patch`](../apk/termux-app-rename.patch)
   改 `applicationId`、`TERMUX_PACKAGE_NAME`、strings.xml，使 termux-app 变成新包名
   （Java `namespace` 保持 `com.termux` 不动，所以代码不用大改）。

2. **自定义 bootstrap 构建脚本** → [`build-custom-bootstrap.sh`](build-custom-bootstrap.sh)
   clone termux-packages → 改 `TERMUX_APP__PACKAGE_NAME` → `run-docker.sh build-bootstraps.sh`
   → 产出 `bootstrap-aarch64.zip`（前缀已换成新包名）。

3. **CI 编排** → [`../.github/workflows/build-apk-renamed.yml`](../.github/workflows/build-apk-renamed.yml)
   两段：先重建 bootstrap（手动触发、一次性），再用它 + 两个补丁编译 APK。

## 一次性重建 bootstrap（本地）

```bash
# 需要 Docker；构建很重（数小时）
bash bootstrap/build-custom-bootstrap.sh com.dsh.termux aarch64
# 产物: termux-packages/bootstrap-aarch64.zip （脚本会打印其 SHA256）
```

## 或走 GitHub Actions

仓库 Actions 页 → **「Build DSH APK (改包名共存版)」** → Run workflow → 填包名/架构 →
两个 job 依次跑：`build-bootstrap`（重）→ `build-apk`。

> ⚠️ bootstrap 重建在 GitHub 免费 runner（2 核 7G）上可能超时/OOM。真跑不动就换
> `ubuntu-latest-4-cores`（更大）或自建 runner，再把产出 zip 作为 release 资产复用。

## 编译 APK（拿到 bootstrap 后）

```bash
git clone https://github.com/termux/termux-app && cd termux-app
git apply ../apk/termux-app-firstboot.patch
git apply ../apk/termux-app-rename.patch
mkdir -p app/src/main/assets/first-boot-extra
cp ../apk/first-boot.sh app/src/main/assets/
cp ../dsh-termux/mobile/mobile.css app/src/main/assets/first-boot-extra/
cp ../dsh-termux/env/dsh.env.example app/src/main/assets/first-boot-extra/
# 放自定义 bootstrap，并把它的 SHA256 写进 build.gradle 的 aarch64 那一行
cp ../bootstrap-aarch64.zip app/src/main/cpp/bootstrap-aarch64.zip
./gradlew :app:assembleDebug   # 产物 arm64 的 APK 装手机即可，与官方 Termux 共存
```

## 之后 DSH 升级

**永远不需要重编 APK/bootstart**，在新 Termux 里：

```sh
npm i -g @deepseek-ai/dsh
```

## 安全

- bootstrap / APK 里**不含任何 API Key**；密钥仍由最终用户本机填入（见 `../apk/first-boot.sh`）。
