# CodePilot 本地运行教程

从 GitHub 克隆代码到本地后，按照以下步骤分别启动 Server、Bridge、iOS App 三端。

---

## 前置条件

| 工具 | 版本要求 | 用途 | 安装方式 |
|------|---------|------|---------|
| **Node.js** | >= 18 | Server + Bridge 运行时 | https://nodejs.org/ |
| **npm** | >= 9 | 包管理 | 随 Node.js 安装 |
| **Git** | 任意 | 克隆代码 | https://git-scm.com/ |
| **Xcode** | >= 15 | iOS App 编译 | Mac App Store |
| macOS | Ventura+ | Xcode 需要 | Apple |

> Bridge 和 Server 在 macOS / Linux / Windows 上都可以运行。iOS App 只能在 macOS 上的 Xcode 中编译。

---

## 第一步：克隆代码

```bash
git clone https://github.com/AllenLin1/ClaudeCodeMobileIDE.git
cd ClaudeCodeMobileIDE
```

---

## 第二步：启动 Server（Cloudflare Workers 本地模式）

Server 使用 Cloudflare `wrangler dev` 在本地运行，不需要部署到云端。

```bash
# 进入 server 目录
cd server

# 安装依赖
npm install

# 一键生成 RS256 密钥并写入 .dev.vars
npm run setup
```

`npm run setup` 做了什么：
- 生成一对 RS256 公私钥
- 写入 `server/.dev.vars` 文件（wrangler 本地开发的环境变量）
- 在终端打印公钥（后面 Bridge 要用）

接下来启动本地服务器：

```bash
npx wrangler dev
```

第一次运行时 wrangler 可能会提示登录 Cloudflare，有两个选择：
- **推荐**：按提示登录（免费账号即可），这样 KV 和 Durable Objects 在本地完全可用
- **跳过登录**：按 `n` 跳过，大部分功能仍然可用（KV 会使用本地模拟）

成功后你会看到：

```
⎔ Starting local server...
[wrangler] Ready on http://localhost:8787
```

**验证 Server 在运行：**

打开一个新终端窗口：

```bash
# 健康检查
curl http://localhost:8787/health
# 应该返回: {"status":"ok","version":"1.0.0"}

# 测试认证接口
curl -X POST http://localhost:8787/auth \
  -H "Content-Type: application/json" \
  -d '{"user_id": "local_test_user"}'
# 应该返回: {"token":"eyJ...", "payload":{...}}
```

> Server 保持运行，不要关闭这个终端窗口。

---

## 第三步：启动 Bridge（桌面端）

Bridge 是运行在你电脑上的命令行程序，负责对接 Claude Agent SDK。

打开一个**新终端窗口**：

```bash
# 进入 bridge 目录
cd bridge

# 安装依赖
npm install

# 编译 TypeScript
npm run build
```

编译成功后，启动 Bridge 并指向本地 Server：

```bash
node bin/cli.js start --server http://localhost:8787
```

成功后你会看到：

```
╔══════════════════════════════════════╗
║       CodePilot Bridge Ready          ║
╠══════════════════════════════════════╣
║  Pairing Code:  A1B2C3              ║
║                                        ║
║  Scan the QR code with CodePilot App  ║
║  or enter the pairing code manually.   ║
╚══════════════════════════════════════╝

  (QR 码会显示在这里)

[bridge] Connected to relay
[bridge] Waiting for app connection...
```

这说明 Bridge 已经：
1. 生成了 E2E 加密密钥对
2. 连接到了本地 Server 的 Relay
3. 在等待 iOS App 配对

> Bridge 保持运行，不要关闭这个终端窗口。

**如果你想连接真正的 Claude Agent SDK**（可选）：

```bash
# 在 bridge 目录安装 Claude Code SDK
npm install @anthropic-ai/claude-code

# 设置你的 Anthropic API Key
export ANTHROPIC_API_KEY=sk-ant-api03-xxxxx

# 重新启动 bridge
node bin/cli.js start --server http://localhost:8787
```

---

## 第四步：运行 iOS App

### 4a. 创建 Xcode 项目

由于我们没有包含 `.xcodeproj` 文件（它包含机器特定的路径），你需要在 Xcode 中手动创建项目：

1. 打开 **Xcode**
2. **File → New → Project**
3. 选择 **iOS → App**
4. 填写信息：
   - Product Name: `CodePilot`
   - Team: 你的开发者账号（可以选 Personal Team）
   - Organization Identifier: `com.yourname`（任意）
   - Interface: **SwiftUI**
   - Storage: **SwiftData**
   - Language: **Swift**
5. 保存到任意位置（比如桌面）

### 4b. 导入源代码

1. 在 Xcode 左侧的 Project Navigator 中，**删除** Xcode 自动生成的 `ContentView.swift` 和 `CodePilotApp.swift`（右键 → Delete → Move to Trash）
2. 把仓库中 `ios/CodePilot/` 下的**所有文件和文件夹**拖到 Xcode 的 Project Navigator 中
   - 勾选 "Copy items if needed"
   - 勾选 "Create groups"
   - Target 选择 `CodePilot`
3. 同样把 `ios/CodePilot/Resources/Assets.xcassets` 拖进去（如果还没有）

### 4c. 添加 RevenueCat 依赖

1. **File → Add Package Dependencies...**
2. 搜索框粘贴: `https://github.com/RevenueCat/purchases-ios-spm.git`
3. 选择版本规则: **Up to Next Major** (5.0.0)
4. 点击 **Add Package**
5. 在弹出的产品选择中，勾选 **RevenueCat**，点击 **Add Package**

> 注意：当前代码中 RevenueCat 是 mock 实现，即使不添加这个依赖也可以编译运行。如果遇到 import 问题，可以暂时注释掉 `RevenueCatService.swift` 中的 import 行。

### 4d. 项目设置

1. 点击左侧项目名 → **TARGETS → CodePilot**
2. **General** 标签页:
   - Minimum Deployments: **iOS 17.0**
   - Bundle Identifier: `com.yourname.codepilot`
3. **Signing & Capabilities** 标签页:
   - Team: 选择你的 Apple ID
   - 勾选 Automatically manage signing
4. **Info** 标签页:
   - 确保 Privacy - Camera Usage Description 已填写（扫码用）

### 4e. 编译运行

1. 选择模拟器：顶部选择 **iPhone 15 Pro**（或任意 iOS 17+ 模拟器）
2. 点击 **▶ Run** 或按 `Cmd + R`
3. App 启动后会进入 Onboarding 引导页

### 4f. 在模拟器中配对

由于模拟器不支持真实摄像头扫码，使用**手动输入配对码**：

1. 在 Onboarding 第一步点击 **Next**
2. 在第二步，点击 **手动输入配对码**
3. 输入 Bridge 终端中显示的 Pairing Code（如 `A1B2C3`）
4. 点击 **Connect**
5. 如果看到 "You're All Set!" 页面，说明配对成功

---

## 第五步：端到端验证

此时你应该有 3 个终端窗口在运行：

```
终端 1: server/  → npx wrangler dev          (http://localhost:8787)
终端 2: bridge/  → node bin/cli.js start ...  (等待 app 连接)
终端 3: Xcode    → iOS App 在模拟器中运行
```

验证流程：

1. **App 中创建会话**：点击右上角 "+" → 填写 Session Name（如 "Test"）→ 填写 Project Directory（如 `~/Desktop`）→ 点击 Create Session
2. **发送消息**：在对话页底部输入框输入 "Hello"，点击发送
3. **Bridge 终端观察**：应该能看到收到消息的日志
4. **如果安装了 Claude SDK + 有 API Key**：Claude 会处理消息并返回结构化响应，App 中会显示 AI 回复

---

## 不用 App 也能测试 WebSocket 中继

如果你暂时不想编译 iOS App，可以用 `wscat` 模拟 App 端来测试 Server + Bridge 的通信：

```bash
# 安装 wscat
npm install -g wscat

# 查看 Bridge 连接的 Room ID（在 Bridge 终端的日志 / QR URL 中）
# 假设 Room ID 是 abc-123-def

# 在新终端中，作为 "app" 角色连接到同一个 Room
wscat -c "ws://localhost:8787/relay/abc-123-def?role=app"

# 连接成功后，输入 JSON 消息：
{"type":"auth","token":"dev"}
# Bridge 会返回 auth:success

{"type":"session:list"}
# Bridge 会返回会话列表

{"type":"session:create","name":"Test","cwd":"/tmp","model":"default"}
# Bridge 会创建一个新会话
```

---

## 运行测试

```bash
# Server 单元测试 (6 tests)
cd server && npm test

# Bridge 单元测试 (41 tests)
cd bridge && npm test
```

---

## 常见问题

### Q: `wrangler dev` 报错 "KV namespace not found"
A: 这是因为 `wrangler.toml` 中有一个 placeholder KV ID。本地开发时 wrangler 会自动创建本地 KV，通常不影响。如果确实报错，可以运行：
```bash
npx wrangler kv:namespace create LICENSING_KV
```
然后把返回的 ID 填入 `wrangler.toml`。

### Q: Bridge 报错 "Cannot find module '../dist/index'"
A: 需要先编译 TypeScript：
```bash
cd bridge && npm run build
```

### Q: Bridge 连接 Server 失败
A: 确保 Server 在运行（`npx wrangler dev`），并且 Bridge 使用的 URL 正确（`--server http://localhost:8787`）。

### Q: Xcode 编译报错 "Cannot find type 'xxx'"
A: 确保：
1. 所有 `ios/CodePilot/` 下的文件都已添加到 Xcode 项目中
2. 每个 `.swift` 文件的 Target Membership 勾选了 `CodePilot`
3. iOS Deployment Target 设置为 17.0

### Q: 模拟器中 App 无法连接到 Bridge
A: 模拟器默认可以访问 `localhost`。确认:
1. Server 在运行 (`localhost:8787`)
2. Bridge 在运行并且已连接到 Server
3. App 中的 Server URL 指向 `http://localhost:8787`

### Q: 没有 Anthropic API Key 可以测试吗？
A: 可以。Bridge 在找不到 Claude SDK 时会进入 simulation 模式，返回模拟消息。UI 交互、加密通信、会话管理等功能仍然可以完整测试。

---

## 目录总览

```
终端窗口 1 (Server):
  cd server && npm install && npm run setup && npx wrangler dev

终端窗口 2 (Bridge):
  cd bridge && npm install && npm run build && node bin/cli.js start --server http://localhost:8787

终端窗口 3 (iOS):
  Xcode → 打开项目 → Cmd+R 运行到模拟器

可选 - 不用 App 的测试:
  wscat -c "ws://localhost:8787/relay/ROOM_ID?role=app"
```
