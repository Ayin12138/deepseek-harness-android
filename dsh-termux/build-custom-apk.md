# 把「预装好 DeepSeek Harness 的 Termux」编译成自定义 APK

本文说明如何在你自己的电脑上，把本目录 `dsh-termux/` 的一键装机内容**固化进一个自定义 Termux APK**，让用户装上 APK 后第一次打开就能（近乎）直接得到可用的 DeepSeek Harness。

> ⚠️ 编译 APK 需要 **Android SDK + NDK + Gradle**（本沙盒环境没有，无法代你产出 `.apk`）。本文是给「你自己机器」的完整操作指南。

---

## 0. 先说清楚：两种「预装」的取舍

| 方案 | 产物 | 预装程度 | 难度 | 维护成本 |
|---|---|---|---|---|
| **A. 编译官方 termux-app** | 自定义签名的 Termux APK | 只含 Termux；DSH 用 `install.sh` 一键装 | ★☆☆ | 低 |
| **B. 自定义 bootstrap（真·预装）** | 单 APK，首启自带 Node+DSH | Node、pnpm、DSH、配置全部内置 | ★★★ | 高 |

- 方案 A 是「把安装器 + 装 DSH 变成一个 APK + 一条命令」，最实用、最容易长期维护。
- 方案 B 是真正意义上的「一个 APK 即完整产品」，但需要构建 termux-packages 的 bootstrap rootfs，工作量大、且每次 DSH 升级都要重建。

**强烈建议先用方案 A 上线，再按需升级到方案 B。**

---

## 1. 前置要求（你的电脑）

- 64 位 Linux / macOS / Windows + 至少 16GB 内存、30GB 磁盘（SDK 很占空间）
- [Android Studio](https://developer.android.com/studio)（自带 SDK），或单独装 SDK + JDK 17
- NDK（方案 B 需要；方案 A 用不到 NDK）
- `git`、`bash`

---

## 2. 方案 A：编译官方 termux-app 得到 APK

Termux 的安卓壳是开源的（GPLv3）：https://github.com/termux/termux-app

```bash
git clone https://github.com/termux/termux-app
cd termux-app
# 用 Android Studio 打开，或命令行：
./gradlew assembleDebug
```

产物在 `app/build/outputs/apk/debug/app-debug.apk`（或 release，需要自己配签名）。

这个 APK 装上后就是标准 Termux。然后让用户在你的 `dsh-termux/` 里跑一次：

```sh
pkg update -y && pkg install -y git
git clone <你的仓库地址> dsh-termux
cd dsh-termux && bash install.sh && bash configure.sh && bash start.sh
```

→ 一条克隆 + 三条命令，即可得到完整 DSH。这已经满足「APK + 一键装机 + 环境配置完善」。

### 2.1 把装机包打进 APK 资产（更顺滑）

可以在 termux-app 里把 `dsh-termux/` 作为 asset 内置，首次启动自动解压到 `~`：

1. 把 `dsh-termux/` 拷贝到 `app/src/main/assets/dsh-termux/`。
2. 在首次启动回调里，解压 asset 到 `$HOME/dsh-termux/` 并执行 `install.sh`。
3. 重新 `assembleDebug`。

> 具体 hook 点随 termux-app 版本变化，参考其 `TermuxBootstrap` / `TermuxConstants` 源码。此处给出思路，改动要对照当前版本源码。

---

## 3. 方案 B：真·预装 DSH（自定义 bootstrap）

Termux 首次运行时，会从网络下载一个「bootstrap」基础根文件系统（含 apt、bash、coreutils 等）。预装的关键就是**把 Node、pnpm、DSH、配置打进这个 bootstrap**。

### 3.1 构建自定义 bootstrap

1. 克隆 https://github.com/termux/termux-packages
2. 利用其官方脚本生成 bootstrap：

```bash
# termux-packages 的 CI 用这个脚本生成 bootstrap：
./scripts/generate-bootstraps.sh
```

3. 在 bootstrap 里追加 DSH 安装逻辑：修改 bootstrap 构建流程，在生成 rootfs 后执行：

```bash
# 进入 rootfs 后（模拟）
pkg install -y nodejs-lts git build-essential python binutils clang make tmux openssh
npm install -g @deepseek-ai/dsh
# 写入 dsh-termux 的配置模板与启动脚本
```

> 实际操作通常在 Docker 容器里跑 aarch64 rootfs（`qemu-user-static`），是 termux-packages 官方的构建方式。这块工作量和 CI 配置都比较重。

### 3.2 让 termux-app 使用你的 bootstrap

termux-app 的 bootstrap 下载地址在其源码常量里（`app/src/main/java/com/termux/app/TermuxConstants.java` 或对应常量类）：

```java
// 把 bootstrap 下载 URL 指向你自建的 https 地址 / 或内置到 asset
public static final String TERMUX_BOOTSTRAP_URL = "https://你的域名/bootstrap-aarch64.zip";
```

两种方式：
- **自建 URL**：把你的 `bootstrap-*.zip` 挂到一个 HTTPS 地址，改 URL。
- **内置 asset**：把 zip 放进 `app/src/main/assets/`，改 bootstrap 加载逻辑走 asset。

### 3.3 编译

```bash
cd termux-app
./gradlew assembleRelease   # 配置好签名
```

得到「首启即含 Node+DSH」的单 APK。

---

## 4. 签名与分发

- `debug` APK 只能侧载调试；分发用 `release` + 你自己的 keystore：

```bash
keytool -genkey -v -keystore dsh.keystore -alias dsh -keyalg RSA -keysize 4096 -validity 10000
```

- 在 `app/build.gradle` 配 `signingConfigs`，或 Android Studio → Build → Generate Signed Bundle/APK。
- 可选：用 [F-Droid](https://f-droid.org) 的 `Repomaker` 自建仓库分发，支持自动更新。

---

## 5. 安全红线（务必遵守）

1. **绝不要把真实 `DEEPSEEK_API_KEY`、GitHub Token 打进 APK**。APK 是分发的二进制，任何被解包的人都能读到里面的字符串。密钥必须由最终用户在装好之后，通过 `configure.sh` 或 Web UI 自己填入。
2. bootstrap 里的默认配置只放**模板/占位符**（`.env.example`），不放任何真实凭证。
3. 若用自建 bootstrap URL，务必 **HTTPS + 校验和**（termux-app 已有 SHA256 校验机制），防止供应链被篡改。

---

## 6. 维护

- DSH 升级：改 `install.sh` 里的 `npm i -g @deepseek-ai/dsh`（可加版本号锁定，如 `@0.1.0-rc.7`）。
- 方案 B 每次升级 DSH 都要重建 bootstrap 并重新发版 APK；方案 A 只需让用户重跑 `install.sh`。

---

## 参考链接

- termux-app：https://github.com/termux/termux-app
- termux-packages：https://github.com/termux/termux-packages
- Termux:Boot：https://github.com/termux/termux-boot
- DeepSeek Harness：https://github.com/deepseek-ai/deepseek-harness
