# 方案 B · 把 DeepSeek Harness 预装进自定义 Termux APK

目标：用户**装一个 APK、打开一次**，DSH 就自动装好并可用（零手动步骤）。

原理：Termux 的安卓壳（termux-app，GPLv3）首次启动时完成 bootstrap 初始化。
我们把 [`first-boot.sh`](first-boot.sh) 作为 asset 打进 APK，并在首次启动回调里执行它，
由它自动完成「装工具链 → `npm i -g @deepseek-ai/dsh` → 配密钥/移动 UI」。

---

## 一、本地编译（需要 Android Studio / SDK + JDK 17）

```bash
git clone https://github.com/termux/termux-app
cd termux-app

# 1) 把 first-boot.sh 及配套文件放进 asset
mkdir -p app/src/main/assets/first-boot-extra
cp /path/to/apk/first-boot.sh app/src/main/assets/
cp -r /path/to/dsh-termux/mobile/mobile.css app/src/main/assets/first-boot-extra/
cp /path/to/dsh-termux/env/dsh.env.example app/src/main/assets/first-boot-extra/

# 2) 在首次启动回调里执行 first-boot.sh（见下方补丁）

# 3) 编译
./gradlew assembleDebug   # 产物 app/build/outputs/apk/debug/app-debug.apk
```

## 二、首次启动回调（关键一步）

termux-app 源码里，bootstrap 完成后的入口是 `TermuxBootstrap` / `TermuxService`
（随版本变动，以当前源码为准）。在其 bootstrap 成功之后追加：

```java
// 伪代码：bootstrap 完成后执行 asset 里的 first-boot.sh
File f = new File(context.getFilesDir(), "home/.termux/first-boot.sh");
// 从 assets 拷贝 first-boot.sh 到 $HOME/.termux/，然后：
Runtime.getRuntime().exec(new String[]{"/data/data/com.termux/files/usr/bin/bash", f.getAbsolutePath()});
```

> 不同版本 hook 点不同，请对照当前 termux-app 源码的 `TermuxBootstrap` 类。
> 本项目不 fork termux-app 源码，避免维护分叉；用补丁 + 构建脚本的方式接入。

## 三、云端编译（推荐，免装 Android SDK）

见仓库根目录 [`.github/workflows/build-apk.yml`](../.github/workflows/build-apk.yml)：
GitHub Actions 会 `git clone termux-app` → 拷贝 `first-boot.sh` → 打补丁 → `./gradlew assembleDebug`
→ 上传 APK 到 Artifacts。改代码 push 一次就出一个 APK。

## 四、真·离线预装（进阶）

上面是「首启自动装机」（首启需联网）。若要**首启离线可用**，要把 Node+DSH 直接烤进
bootstrap rootfs，见 [`../bootstrap/README.md`](../bootstrap/README.md)。

## 五、安全

- **不要把 `DEEPSEEK_API_KEY` 写进 `first-boot.sh` 或 asset**。可选从 `/sdcard/dsh.env`
  读取用户自放的密钥（见脚本第 2 步），或让用户装好后在 Web UI 里填。
