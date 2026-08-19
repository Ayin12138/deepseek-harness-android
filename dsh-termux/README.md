# DeepSeek Harness · Termux 移动版

把 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)（`@deepseek-ai/dsh`）完整跑在你的安卓手机上的一键装机包。

> 原理：**Termux 是安卓上的 Linux 用户态环境**（自带 bash、git、apt/pkg、可装 Node.js）。
> 我们把 DSH 的 Node.js 后端跑在 Termux 里，手机自带的浏览器打开 `http://127.0.0.1:3080` 使用。
> 智能体在**手机本地**执行（bash、文件读写、子代理等），不需要远程服务器。

---

## ⚠️ 重要提醒（先看这个）

1. **不要在聊天/日志里贴 API Key 或 GitHub Token**。任何 `ghp_...`、`sk-...` 一旦发出去就等于公开，请立刻到对应平台吊销并重新生成，只写进本机的配置文件。
2. **`dsh web` 出于安全只监听 `127.0.0.1`**（`--host 0.0.0.0` 被官方刻意禁止，因为会向网络暴露远程代码执行）。手机本机访问不受影响；要从**别的设备**访问，用文末的 SSH 隧道。

---

## 目录结构

```
dsh-termux/
├── README.md                  ← 本文档
├── install.sh                 ← 一键装机（装工具链 + Node + DSH）
├── configure.sh               ← 交互式配置 API Key / 模型 / 端口
├── start.sh / stop.sh / status.sh   ← 手动启停
├── env/
│   └── dsh.env.example        ← 环境变量模板
├── boot/
│   └── dsh.sh                 ← 开机自启脚本（配合 Termux:Boot）
├── services/
│   └── dsh/run                ← termux-services(runit) 服务定义
├── mobile/
│   ├── mobile.css             ← 移动端优化样式
│   └── inject-mobile-ui.sh    ← 把 mobile.css 注入到 Web UI
└── build-custom-apk.md        ← 把预装好的 DSH 编译进自定义 Termux APK
```

---

## 快速开始（三步）

```sh
# 1. 安装 Termux（F-Droid 或 GitHub，见下），打开后先：
pkg update -y

# 2. 拉取本装机包
pkg install -y git
git clone <本目录的地址> dsh-termux   # 或直接把 dsh-termux/ 拷进手机
cd dsh-termux

# 3. 安装 + 配置 + 启动
bash install.sh
bash configure.sh      # 输入 DEEPSEEK_API_KEY 等
bash start.sh
```

然后在手机浏览器打开 **http://127.0.0.1:3080**。

---

## 一、安装 Termux

**推荐从 F-Droid 安装**（Google Play 版本已停更且 API 受限）：

- F-Droid：https://f-droid.org/packages/com.termux/
- GitHub Releases：https://github.com/termux/termux-app/releases （`termux-app_*.apk`）

> 建议同时装 **Termux:Boot**（开机自启用）：https://f-droid.org/packages/com.termux.boot/

装好打开，可选跑一次 `termux-setup-storage`（授予存储权限）。

---

## 二、`install.sh` 做了什么

1. `pkg update` + 安装工具链：`nodejs-lts`（Node 22 LTS，DSH 需要 ≥22）、`git`、`build-essential`、`python`、`binutils`、`clang`、`make`、`tmux`、`openssh`、`termux-services`。
2. `npm install -g @deepseek-ai/dsh`（全局安装，`dsh` 命令进入 PATH）。
3. 创建 `~/.dsh` 配置目录、`.env` 模板、`~/.termux/boot/` 与 services 目录。
4. 注入移动端 UI（见下）。

> 首次安装会**编译原生模块 `node-pty`**（终端功能需要），所以必须先装 `build-essential python binutils`——`install.sh` 已自动处理。若编译失败，见「常见问题」。

---

## 三、环境配置

### 3.1 密钥优先级（DSH 官方分层，越高越优先）

1. 启动 shell 的**进程环境变量**（只读，最高）
2. `~/.dsh/.credentials.yaml`（DSH 自管理的密钥库）
3. `<当前目录>/.env`
4. `~/.dsh/.env`（只读回退，最低）

`configure.sh` 会写入 **`~/.dsh/.credentials.yaml`**（并 `chmod 600`）作为主配置。

### 3.2 关键环境变量

| 变量 | 作用 | 示例 |
|---|---|---|
| `DEEPSEEK_API_KEY` | DeepSeek 官方 API 密钥（默认 provider 的密钥引用） | `sk-...` |
| `DEEPSEEK_BASE_URL` | 端点（可指向内网网关/代理） | `https://api.deepseek.com` |
| `DSH_HOME` | 配置根目录（默认 `~/.dsh`） | `~/dsh-data` |
| `DSH_PORT` | Web 端口（本装机包用，DSH 默认 3080） | `8080` |

### 3.3 默认模型

DSH 内置 provider `deepseek-official`，模型目录：`deepseek-v4-flash`（快）、`deepseek-v4-pro`（强）。
启动后可在 Web UI 的 **Settings → Models** 里切换 provider/model；`~/.dsh/.credentials.yaml` 里也可写 `DEEPSEEK_API_KEY` 之外的自定义 provider 密钥。

---

## 四、移动端 UI

DSH 前端是 React 单页应用，已自带 `<meta name="viewport">`，并由 `--dsw-*` 设计令牌驱动样式。
`mobile/` 里的方案通过**覆盖设计令牌 + 响应式规则**做移动端优化（不改动、不重新编译前端源码）：

- 阻止安卓浏览器字号自动放大（`text-size-adjust`）；
- 去掉点击高亮、开启 `touch-action: manipulation`（消除点击延迟）；
- 适配刘海屏/底部手势条的 `env(safe-area-inset-*)` 安全区；
- 窄屏下缩放 markdown/标题字号、代码块横向滚动、正文自动换行防溢出；
- 粗指针（触屏）设备增大交互热区、滚动惯性。

`install.sh` 会自动把 `mobile.css` 注入到全局包的前端目录；也可手动执行 `bash mobile/inject-mobile-ui.sh`。

> 说明：桌面式「侧边栏 + 主面板」的整体布局由 JS 布局引擎控制（内联样式），纯 CSS 无法把它改成抽屉式导航；彻底重排需要前端 React 源码（npm 发布包只含构建产物）。本方案做到的是**在现有布局下最大化移动端可用性**，这是不侵入源码的最优解。

---

## 五、启停

```sh
bash start.sh    # 后台启动，日志 ~/.dsh/dsh.log，PID ~/.dsh/dsh.pid
bash status.sh   # 查看是否在跑、监听端口
bash stop.sh     # 停止
```

手动前台调试：`dsh web`（Ctrl-C 停止）。

---

## 六、开机自启（二选一）

### 方式 A：termux-services（推荐，崩溃自动拉起）

```sh
pkg install -y termux-services
# 关闭并重开 Termux 一次，让 services 生效
sv-enable dsh     # 开机自启 + 常驻
sv status dsh     # 查看状态
sv down dsh       # 临时停
sv-disable dsh    # 取消自启
```

### 方式 B：Termux:Boot 脚本

装好 Termux:Boot 后，`install.sh` 已把 `boot/dsh.sh` 放到 `~/.termux/boot/`。
手机每次开机，Termux:Boot 会执行它，自动拉起 `dsh web`。

---

## 七、从别的设备访问（SSH 隧道）

因为 `--host 0.0.0.0` 被禁用，跨设备访问走 SSH 端口转发（安全且无需改 DSH）：

```sh
# 在 Termux 里开启 sshd
pkg install -y openssh
passwd                       # 设个 ssh 密码
sshd
```

在**另一台设备/电脑**上：

```sh
ssh -L 3080:127.0.0.1:3080 <termux用户名>@<手机IP> -p 8022
# 然后访问 http://127.0.0.1:3080
```

> Termux 的 sshd 默认端口是 **8022**；手机 IP 用 `ip -4 addr` 查看（同一 WiFi 下）。

---

## 八、常见问题

| 现象 | 处理 |
|---|---|
| `npm install` 编译 `node-pty` 失败 | 先 `pkg install -y build-essential python binutils clang make`，再重装；确保是 **nodejs-lts（Node 22）** |
| `dsh: command not found` | `export PATH="$PREFIX/bin:$PATH"`，或 `npm i -g @deepseek-ai/dsh` 重新装 |
| 打开 3080 是空白/404 | `bash status.sh` 看进程与端口；`cat ~/.dsh/dsh.log` 看日志 |
| 提示 `no API key` | `bash configure.sh` 重新写入 `DEEPSEEK_API_KEY`，或 `export DEEPSEEK_API_KEY=...` 后重启 |
| 沙箱相关报错（Landlock） | Android 内核默认无 Landlock；DSH 的 web 模式用本地 bash 执行，不依赖 Landlock。如遇 `node-addon-landlock-run` 编译失败，属可选沙箱依赖，可忽略 |
| 电池/后台被杀 | 把 Termux 加入系统电池优化白名单；用 termux-services 常驻 |

---

## 九、限制与说明

- **本机完整功能**：bash 执行、文件读写、子代理、worker 线程、tmux、git 均可在 Termux 内正常工作（Termux 提供 Linux 工具链）。
- **性能**：手机算力/内存有限，跑大型智能体任务（大量子代理、长时间编译）速度会明显慢于电脑。
- **沙箱**：`dsh web` 默认走**本地直接执行**（非 Landlock 沙箱），请在受控目录运行，别让 agent 拿到高权限数据。
- **APK 预装**：把「装好 DSH 的 Termux」真正打包成一个独立 APK，需要重新编译 termux-app，见 [`build-custom-apk.md`](build-custom-apk.md)。
