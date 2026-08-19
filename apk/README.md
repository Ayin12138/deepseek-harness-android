# 方案 B · 把 DeepSeek Harness 预装进自定义 Termux APK

目标：用户**装一个 APK、打开一次**，DSH 就自动装好并可用（零手动步骤）。

原理：Termux 的安卓壳（termux-app，GPLv3）首次启动时完成 bootstrap 初始化。
我们把 [`first-boot.sh`](first-boot.sh) 作为 asset 打进 APK，并在 bootstrap 完成后执行它，
由它自动完成「装工具链 → `npm i -g @deepseek-ai/dsh` → 配密钥/移动 UI」。

**首启回调的补丁已写好**：[`termux-app-firstboot.patch`](termux-app-firstboot.patch)，
可直接干净应用到官方 termux-app 源码（`TermuxInstaller.java`）。CI 会自动应用它。

---

## 一、补丁做了什么

对 `app/src/main/java/com/termux/app/TermuxInstaller.java`：

1. 新增 `runFirstBootScript(Context)`：bootstrap 成功后，把 `assets/first-boot.sh`
   与 `assets/first-boot-extra/*` 拷到 `~/.termux/`，并用 Termux 环境后台执行
   `first-boot.sh`（进程环境用 `TermuxShellEnvironment` 注入，`PREFIX/PATH/HOME` 齐全）。
2. 新增 `copyAsset(...)`：把单个 asset 写到目标文件。
3. 在 `setupBootstrapIfNeeded()` 的 bootstrap 成功后、`whenDone.run()` 前调用它。

> 补丁是针对当前 termux-app `main`（提交 `3df69d1`）生成的。若 termux-app 上游
> 改动导致冲突，用 `git apply --3way` 或重新对当前源码生成补丁即可。

## 二、本地编译（需要 Android Studio / SDK + JDK 17）

```bash
git clone https://github.com/termux/termux-app
cd termux-app

# 1) 放资产
mkdir -p app/src/main/assets/first-boot-extra
cp /path/to/apk/first-boot.sh app/src/main/assets/
cp /path/to/dsh-termux/mobile/mobile.css app/src/main/assets/first-boot-extra/
cp /path/to/dsh-termux/env/dsh.env.example app/src/main/assets/first-boot-extra/

# 2) 打首启补丁
git apply /path/to/apk/termux-app-firstboot.patch

# 3) 编译
./gradlew assembleDebug   # 产物 app/build/outputs/apk/debug/app-debug.apk
```

## 三、云端编译（推荐，免装 Android SDK）

见 [`.github/workflows/build-apk.yml`](../.github/workflows/build-apk.yml)：
`checkout` → `clone termux-app` → 注入资产 → 应用补丁 → `./gradlew assembleDebug`
→ 上传 APK 到 Artifacts。push 一次出一个 APK，或在 Actions 页手动触发。

## 四、真·离线预装（进阶）

上面是「首启自动装机」（首启需联网）。若要**首启离线可用**，要把 Node+DSH 直接烤进
bootstrap rootfs，见 [`../bootstrap/README.md`](../bootstrap/README.md)。

## 五、安全

- **不要把 `DEEPSEEK_API_KEY` 写进 `first-boot.sh` 或 asset**。可选从 `/sdcard/dsh.env`
  读取用户自放的密钥（见脚本第 2 步），或让用户装好后在 Web UI 里填。
