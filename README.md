# DeepSeek Harness for Android

把 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)（`@deepseek-ai/dsh`）跑在安卓手机上，并打包成 APK 的完整工程。

> 一句话原理：DSH 是一个 Node.js 智能体后端（需要 bash/子进程/文件系统），安卓原生跑不了；
> **Termux 是安卓上的 Linux 用户态环境**，把 DSH 跑在 Termux 里，就获得了「手机本机、功能完整」的智能体。

---

## 两条路线

| | 方案 A · 标准 Termux + 一键装机 | 方案 B · 预装 DSH 的自定义 APK（**本项目主线**） |
|---|---|---|
| 产物 | 标准 Termux APK + `install.sh` | 单个 APK，首启自动装 DSH（或首启即含） |
| 预装程度 | 打开后跑一条命令 | 打开即自动配置 |
| 难度 | ★☆☆ | ★★★ |
| 分发 | 需另配装机包 | 装一个 APK 即用 |

**本项目按方案 B 推进**，方案 A 作为兜底保留在 `dsh-termux/` 里。

---

## 目录结构

```
deepseek-harness-android/
├── README.md                     ← 本文档
├── .gitignore
├── dsh-termux/                   ← 一键装机包（方案 A，也是方案 B 的装机逻辑来源）
│   ├── install.sh                ← 装工具链 + Node + DSH
│   ├── configure.sh              ← 配 API Key / 模型 / 端口
│   ├── start.sh stop.sh status.sh
│   ├── env/  boot/  services/    ← 环境模板 / 开机自启 / 常驻服务
│   ├── mobile/                   ← 移动端优化 UI（mobile.css + 注入脚本）
│   └── build-custom-apk.md       ← 编译自定义 APK 的总指南
├── apk/                          ← 方案 B：自定义 termux-app APK
│   ├── first-boot.sh             ← 首次启动自动装 DSH（打进 APK asset）
│   └── README.md                 ← 如何把它挂进 termux-app 并编译
├── bootstrap/                    ← 方案 B 进阶：真·预置 rootfs（Node+DSH 内建）
│   ├── provision-rootfs.sh       ← 在 termux-packages 环境里预置 DSH
│   └── README.md
└── .github/workflows/
    └── build-apk.yml             ← GitHub Actions 云端编译 APK
```

---

## 快速开始（手机侧）

### 方案 A（最简单，立刻可用）

1. 手机装 Termux（F-Droid）：https://f-droid.org/packages/com.termux/
2. 跑：

```sh
pkg update -y && pkg install -y git
git clone https://github.com/Ayin12138/deepseek-harness-android
cd deepseek-harness-android/dsh-termux
bash install.sh && bash configure.sh && bash start.sh
```

3. 浏览器打开 http://127.0.0.1:3080

### 方案 B（本仓库主线）

见 [`apk/README.md`](apk/README.md)：核心是把 [`apk/first-boot.sh`](apk/first-boot.sh) 打进 termux-app 的 asset，首启自动执行装机；APK 由 GitHub Actions 云端编译（见 [`.github/workflows/build-apk.yml`](.github/workflows/build-apk.yml)）。

---

## 环境配置要点

- **密钥**：`DEEPSEEK_API_KEY`（进程环境变量 > `~/.dsh/.credentials.yaml` > `./.env` > `~/.dsh/.env`）。用 `configure.sh` 写入 `~/.dsh/.credentials.yaml`（自动 chmod 600）。
- **模型**：内置 provider `deepseek-official`，模型 `deepseek-v4-flash` / `deepseek-v4-pro`，可在 Web UI 的 Settings → Models 里切换。
- **端口**：`dsh web` 默认 `127.0.0.1:3080`；`--host 0.0.0.0` 官方禁用，跨设备访问走 SSH 隧道（见 `dsh-termux/README.md`）。
- **移动 UI**：`dsh-termux/mobile/` 通过覆盖 `--dsw-*` 设计令牌做移动端优化。

---

## 安全红线

1. **不要把真实 `DEEPSEEK_API_KEY`、GitHub Token 打进 APK 或提交到仓库**。APK 是可解包的二进制，密钥只能由最终用户本机填入。
2. 仓库只含脚本/文档/模板（`.env.example`），不含任何真实凭证。
3. `dsh web` 只监听本机回环地址，是官方安全设计。

---

## 后续路线（方案 B 完整落地）

1. `apk/first-boot.sh` 首启自动装机 → 用户装一个 APK 即自动配置（零手动步骤）。
2. `bootstrap/` 真·预置 rootfs → 把 Node+DSH 直接烤进 bootstrap，首启离线可用（进阶、构建重）。
3. GitHub Actions 云端出 APK → 无需本地 Android SDK。
