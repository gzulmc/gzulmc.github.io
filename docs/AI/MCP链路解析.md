# 1、带我学习 anthropic ...

**问题详情：**

带我学习 anthropic MCP ,理清 用户提问->Claude Code CLI ->

---

你这个问题本质是在拆 **“Claude Code + MCP + 工具调用” 的完整链路数据流**。我帮你把它从工程视角理清楚，并补全你省略的那一段。

---

# 1. 你要的核心链路（完整版本）

你现在的链路是：

> 用户提问 → Claude Code CLI → ???

正确的完整链路应该是：

> 用户提问
>  → Claude Code CLI（Host）
>  → Claude 模型（LLM 推理）
>  → Tool Router（工具路由层）
>  → MCP Client（协议客户端）
>  → MCP Server（外部工具/系统）
>  → 返回结果
>  → 再回到 LLM 做下一轮推理
>  → CLI 输出

---

# 2. MCP 在 Claude Code 架构里的位置

先明确 MCP 不是“模型能力”，而是：

> **工具标准化通信协议（Tooling Layer）**

它解决的是：

- Claude Code 不需要为 GitHub / DB / Jira 写 N 个 SDK
- 只需要一个 MCP Client
- 对接 N 个 MCP Server

---

# 3. Claude Code CLI 实际做的事情

CLI 本质是一个 **Agent Runtime（运行时容器）**：

它负责：

### ① 输入封装

把你的输入变成：

```json
{
  "messages": [
    {"role": "user", "content": "你的问题"}
  ],
  "tools": [...MCP tools + built-in tools...],
  "system": "Claude Code system prompt"
}
```

---

### ② 发给 Claude 模型

模型会返回两种结果之一：

#### A. 直接回答

```json
{
  "type": "text",
  "content": "最终回答"
}
```

#### B. tool call（关键）

```json
{
  "type": "tool_use",
  "name": "mcp__github__search_issue",
  "input": {
    "query": "bug login"
  }
}
```

---

# 4. MCP 是怎么被触发的（关键）

当 Claude 需要外部信息时：

### Step 1：模型选择工具

例如：

> “去查 GitHub issue”

模型不会直接调用 API，而是：

👉 输出 tool_call

---

### Step 2：Claude Code CLI 拦截 tool_call

CLI 看到：

```
tool_use: mcp__github__search_issue
```

---

### Step 3：进入 MCP Client 层

CLI 会做：

```
MCP Client → 找到 github server
```

---

### Step 4：通过 MCP 协议请求 MCP Server

发送类似：

```json
{
  "tool": "search_issue",
  "args": {
    "query": "bug login"
  }
}
```

---

### Step 5：MCP Server 执行真实动作

比如：

- 调 GitHub API
- 查数据库
- 查 Jira
- 读本地文件

---

### Step 6：返回结构化结果

```json
{
  "issues": [
    {"id": 123, "title": "login crash"}
  ]
}
```

---

### Step 7：返回给 Claude 模型

CLI 把结果塞回 LLM：

```json
{
  "role": "tool",
  "name": "mcp__github__search_issue",
  "content": {...}
}
```

---

### Step 8：LLM 再推理

模型会继续：

> “我已经查到了 issue 123，所以应该这样修……”

---

# 5. 一句话总结 MCP 的作用

MCP 在 Claude Code 中的本质是：

> **把“工具调用”从模型能力，变成可插拔的外部服务系统**

---

# 6. Claude Code + MCP 的整体架构图（抽象）

```
User
 ↓
Claude Code CLI (Agent Runtime)
 ↓
Claude Model (LLM reasoning)
 ↓
Tool Router
 ↓
MCP Client
 ↓
MCP Servers (GitHub / DB / Slack / FS / API)
 ↓
External Systems
```

---

# 7. 关键认知（很多人卡在这里）

## ❌ 错误理解

“MCP 是 Claude 自己的一部分能力”

## ✅ 正确理解

“MCP 是 Claude Code 给模型外挂的标准工具接口”

---

# 8. 再往深一层（你后面一定会用到）

MCP 本质解决三个工程问题：

### ① Tool N×M 问题

不用每个模型对接每个工具

---

### ② Schema 标准化

所有工具统一成：

- input JSON schema
- output JSON schema

---

### ③ 动态能力扩展

Claude Code 不需要升级模型：

👉 只要加 MCP server 就能扩能力

---

# 9. 如果你想继续深入（建议路线）

下一步我可以帮你把这三块彻底讲透：

### A. Claude Code 的 tool loop（核心 while-loop）

### B. MCP Server 如何自己写（Python / TS）

### C. function calling vs MCP vs OpenAI tools 的差异

### D. 为什么 MCP 比 LangChain tool 更“底层”

---

如果你愿意，我们可以下一步直接画：

> **“Claude Code 内部 tool loop + MCP 调度状态机”**

这个会让你彻底看懂 agent 是怎么“活起来”的。

---

# 2、这里出现的几个角色, user...

**问题详情：**

这里出现的几个角色, user,Claude Code CLI, model,

---

你这个是在拆 **Claude Code / MCP 的执行分层角色模型**，很好，这一步如果搞清楚，后面 tool loop、agent、MCP 都是顺的。

我帮你把这 3 个（其实是 4 个核心层）讲清楚：

---

# 1. 四个核心角色（完整视角）

你提到：

> user, Claude Code CLI, model

但实际工程里是 **4 层结构**：

```
User
↓
Claude Code CLI（Agent Runtime / Orchestrator）
↓
Claude Model（LLM 推理引擎）
↓
MCP Tools / External Systems
```

---

# 2. 每个角色到底在干什么（非常关键）

## ① User（用户）

你可以理解为：

> 输入“意图”的来源

特点：

- 只负责说话
- 不知道工具存在
- 不知道 MCP
- 不参与执行流程

例如：

```
“帮我查 GitHub 登录 bug”
```

👉 这只是“意图信号”

---

## ② Claude Code CLI（核心调度器 / Agent Runtime）

这是最关键的一层。

它不是模型，它是：

> **“控制模型执行流程的程序”**

它做 5 件事：

### 1）构造 prompt

把 user input 包装成：

- system prompt
- tool schema
- conversation history

---

### 2）调用 model

```
CLI → LLM API
```

---

### 3）解析 model 输出

判断：

- 是普通文本？
- 还是 tool call？

---

### 4）执行 tool call（MCP 在这里被触发）

```
model → tool_use → CLI intercept → MCP client
```

---

### 5）循环执行（Agent Loop）

```
思考 → 调工具 → 再思考 → 再调工具
```

👉 这是 agent 的本质

---

📌 一句话：

> CLI = “大脑外的执行器 + 调度器”

---

## ③ Claude Model（LLM）

这是：

> **纯推理引擎（stateless reasoning engine）**

它只做一件事：

### 👉 生成下一步 token

包括：

- 回答
- 思考
- tool call

---

但注意：

### ❌ 它不执行任何工具

### ❌ 它不访问网络

### ❌ 它不知道 MCP 是什么实现

它只“建议”：

```json
{
  "tool_use": "search_github"
}
```

---

📌 一句话：

> Model = “决策器（决定做什么）”

---

## ④ MCP / Tools（执行系统）

这一层是：

> **真正干活的外部系统**

比如：

- GitHub API
- DB 查询
- 文件系统
- Slack
- HTTP 服务

---

它只做：

```
input → execution → output
```

不参与推理。

---

# 3. 关键数据流（最重要）

完整流程是：

```
(1) User 提问
    ↓
(2) CLI 包装 prompt
    ↓
(3) Model 推理
    ↓
    ├── A: 直接输出答案 → CLI → User
    └── B: tool call
             ↓
        CLI 解析 tool
             ↓
        MCP Client 调 server
             ↓
        MCP Server 执行
             ↓
        返回结果给 CLI
             ↓
        CLI 再喂回 Model
             ↓
        Model 再推理
             ↓
        输出最终答案
```

---

# 4. 一个关键理解（很多人卡住）

## ❗ Model 和 CLI 的区别

| 层⁠级 | 是⁠什⁠么 | 是⁠否⁠会⁠执⁠行⁠工⁠具 |
| --- | --- | --- |
| Model | 推⁠理⁠器 | ❌ 不⁠会 |
| CLI | 执⁠行⁠器 | ✅ 会 |

---

# 5. MCP 在这个结构里的真实定位

很多人误解 MCP 是“模型能力”，其实不是。

它实际是：

> **CLI ↔ 外部系统 的标准协议层**

可以理解为：

```
Claude Code CLI
   ↓
MCP Client
   ↓
MCP Server（工具实现）
```

---

# 6. 如果换成一个更直观类比

可以这样理解：

## 🧠 Model = 大脑

## 🦾 CLI = 手脚 + 操作系统

## 🌍 MCP = 插件接口（USB / API标准）

## 👤 User = 发任务的人

---

# 7. 一句话总结整个结构

> Claude Code CLI 才是“Agent”，Model 只是“思考引擎”，MCP 是“外部能力接口”。

---

# 8. 如果你下一步想深入（建议）

你现在已经到“理解架构层”了，下一步可以学这三个关键点：

### ① Agent Loop（while循环怎么设计）

### ② tool schema 是怎么被注入 prompt 的

### ③ MCP server 的协议细节（JSON-RPC）

我可以帮你直接画一张：

> **“Claude Code agent loop + MCP 状态机图（工程级）”**

这个看完你基本就能自己写一个 mini Claude Code。

---

# 3、这里出现的几个角色, user...

**问题详情：**

这里出现的几个角色, user , Claude Code CLI, model, mcp server, mcp client, Tool Router, 他们的定位和作用是什么? MCP 协议 是 mcp server 和 mcp client的沟通协议,  mcp server 相当于一个工具tool ? 我知道直接和model交换信息的是Claude Code CLI他们只进行 Claude api 接口规范的调用. 那相当于Claude Code CLI 也是mcp client的身份? Claude Code CLI要通过Claude API调用model,还要与mcp server沟通调用 mcp server的工具服务? 拿到mcp server 返回的数据后在包装数据与Claude交互?

---

你这段理解已经很接近正确架构了，但里面有几个**关键层级边界需要“校准”**，否则后面会越学越乱。我给你按**工业级架构视角**重新梳理一遍。

---

# 1. 先给结论（非常重要）

你最后那段推理里，核心结论是：

> ✔ Claude Code CLI 同时承担 LLM 调用 + MCP Client 调用
>  ✔ MCP Server = 工具执行端
>  ✔ MCP Client = 调用 MCP Server 的协议端
>  ✔ Tool Router = 决定“用不用工具 / 用哪个工具”

是的，但要补一个关键点：

> ⚠️ MCP Client **不是一个独立系统，而是 CLI 内部的一个模块**

---

# 2. 六个角色的“准确分层”

我给你按**职责分层（非常关键）**：

```
┌──────────────────────────────┐
│  User                        │
└─────────────┬────────────────┘
              ↓
┌──────────────────────────────┐
│ Claude Code CLI (Agent Runtime) │
│  - prompt 构造                │
│  - 调 LLM API                │
│  - tool loop                 │
│  - MCP Client（内置）        │
│  - Tool Router               │
└─────────────┬────────────────┘
              ↓
┌──────────────────────────────┐
│ Claude Model (LLM)           │
│  - 纯推理                    │
│  - 决策 tool_call            │
└─────────────┬────────────────┘
              ↓
┌──────────────────────────────┐
│ MCP Client（CLI内部模块）     │
└─────────────┬────────────────┘
              ↓
┌──────────────────────────────┐
│ MCP Server（工具执行器）      │
│  - GitHub / DB / FS / API    │
└──────────────────────────────┘
```

---

# 3. 每个角色的精确定义

## ① User（用户）

### 定位：

> 任务输入者（Intent Source）

### 职责：

- 只负责提出问题
- 不知道 tool / MCP / model 内部结构

---

## ② Claude Code CLI（最核心）

这是整个系统的：

> **Agent Runtime（智能体运行时）**

它不是“调用模型的壳”，而是一个完整 orchestrator。

### 它做 4 件核心事情：

---

### ✔ 1. 调用 Claude API（LLM）

```
CLI → Claude Model API
```

---

### ✔ 2. 管理对话状态（memory / context）

- history
- system prompt
- tool schema

---

### ✔ 3. Tool Router（工具决策分发）

作用：

> 判断 model 输出的是不是 tool call

例如：

```json
tool_use: mcp__github__search
```

然后决定：

- 走 MCP？
- 走本地工具？
- 直接忽略？

---

### ✔ 4. MCP Client（内置模块）

⚠️ 重点来了：

> MCP Client **不是独立进程，是 CLI 内部 SDK**

它做：

- 连接 MCP server
- JSON-RPC 通信
- tool schema 调用
- 返回结果解析

---

📌 一句话：

> CLI = “总控制器 + MCP客户端 + LLM调用器”

---

## ③ Claude Model（LLM）

### 定位：

> 纯推理引擎（stateless reasoning engine）

### 它只做：

- 生成 token
- 决策 tool_call
- 不执行任何工具

---

### 它不会做：

❌ 不调用 MCP
 ❌ 不访问网络
 ❌ 不执行 API

---

📌 一句话：

> Model = “只负责思考，不负责执行”

---

## ④ Tool Router（工具路由器）

这个很多人会忽略。

### 定位：

> tool_call 的“调度判断层”

### 它的作用：

当 model 输出：

```json
tool_use: mcp__github__search
```

Tool Router 判断：

- 这是 MCP tool → 去 MCP Client
- 这是本地 tool → 本地执行
- 这是非法 tool → reject

---

📌 一句话：

> Tool Router = “工具调度分发器”

---

## ⑤ MCP Client

### 定位：

> MCP 协议通信客户端（CLI内部）

### 它负责：

- 连接 MCP server
- 发送 request
- 接收 response

---

### MCP 本质是：

> JSON-RPC 风格的 tool invocation protocol

示例：

```json
{
  "method": "search_issue",
  "params": {
    "query": "login bug"
  }
}
```

---

📌 一句话：

> MCP Client = “工具调用的网络层”

---

## ⑥ MCP Server

### 定位：

> 工具执行器（Tool Runtime）

你可以直接理解为：

> **一个标准化 tool service**

---

### 它可以是：

- GitHub search server
- DB query server
- file system server
- HTTP API wrapper

---

### 它做的事情：

```
input → logic → external system → output
```

---

📌 一句话：

> MCP Server = “真正干活的工具”

---

# 4. 你问的关键问题逐条校准

---

## ❓1：MCP server 相当于 tool 吗？

✔ 正确，但要精确一点：

> MCP Server = Tool 的“运行容器 + 标准接口实现”

不是单纯 function，而是：

- tool + protocol + runtime

---

## ❓2：Claude Code CLI 是 MCP client 吗？

✔ 是，但要修正理解：

> CLI ≠ MCP Client
>  CLI = 包含 MCP Client 的 Agent Runtime

---

## ❓3：CLI 是否同时做 LLM + MCP？

✔ 是的，这是关键点：

### CLI 同时做两件事：

### ① LLM 调用

```
CLI → Claude API
```

### ② MCP 调用

```
CLI → MCP Client → MCP Server
```

---

## ❓4：MCP 返回数据后怎么回到模型？

✔ 你的理解是正确的，但流程要精确：

```
MCP Server → CLI → Tool Result
                    ↓
             再封装为 message
                    ↓
             再喂回 LLM
```

例如：

```json
{
  "role": "tool",
  "name": "mcp__github__search",
  "content": { ... }
}
```

---

## ❓5：CLI 是不是“中间桥梁”？

✔ 是，但更准确是：

> CLI = Agent Controller（控制整个 loop）

不是桥，是“控制系统”。

---

# 5. 最终正确模型（工业级抽象）

```
User
  ↓
Claude Code CLI (Agent Runtime)
  ├── LLM API caller
  ├── Tool Router
  ├── MCP Client
  ↓
Claude Model
  ↓
(tool_call)
  ↓
MCP Client
  ↓
MCP Server
  ↓
External Systems
```

---

# 6. 一句话帮你彻底定性

> Claude Code CLI 是 Agent，大模型只是“思考器”，MCP 是“工具协议层”，MCP Server 是“工具执行端”。

---

# 7. 如果你想继续深入（建议下一步）

我可以带你进入真正核心的部分：

### ✔ MCP 协议长什么样（JSON-RPC细节）

### ✔ tool loop（while循环执行机制）

### ✔ Claude Code 为什么比 LangChain 更“工程化”

### ✔ 如何自己写一个 MCP server（10分钟做一个）

只要你下一步选一个，我可以直接带你写一个 mini Claude Code 级别的 agent。

---

# 4、所以这个 Tool Route...

**问题详情：**

所以这个 Tool Router 其实也是CLI内部的一个模块? CLI是调用 工具function tool 还是 MCP server 也是model 返回给 CLI的数据中是否包含 类似 tool_call 这样的属性字段 来告诉 CLI 是否调用工具以及怎么调用工具(包括传什么参数以及具体的参数值) ? CLI 的Tool Router 调用 工具得到数据后在 包装成 messages 通过 Claude API 调用model 将工具执行的结果和对话的上下文内容 发送给 model?

---

你的理解已经非常接近“工业实现真实形态”了，我帮你把每一个关键点做**精确校正 + 结构化拆解**，避免你后面把 MCP / tool calling 混在一起。

---

# 1. Tool Router 是不是 CLI 内部模块？

✔ 是的，**100% 是 CLI 内部模块**

但要精确一点：

> Tool Router = CLI 内部的 “tool dispatch layer（工具分发层）”

它负责：

- 解析 model 输出
- 判断 tool 类型（本地 / MCP / 内置）
- 选择执行路径

它不是模型的一部分，也不是 MCP 的一部分。

---

# 2. Model 返回的到底是什么？

你这个问题是核心。

## ✔ 正确答案：Model 返回的是“结构化 tool_call”

例如：

```json
{
  "type": "tool_use",
  "name": "mcp__github__search_issue",
  "input": {
    "query": "login bug"
  }
}
```

---

## 📌 关键点

### ✔ 1. model 不知道 MCP

model 只知道：

> “我要调用一个 tool”

它不知道：

- MCP 是什么
- server 在哪
- 怎么发 HTTP / RPC

---

### ✔ 2. tool_call 是“协议级输出”

这个结构是：

> Claude API / OpenAI tools / function calling 的统一范式

---

### ✔ 3. MCP tool 名字只是“命名空间”

比如：

```
mcp__github__search_issue
```

含义：

- mcp → tool 来源（MCP系统）
- github → server name
- search_issue → function

---

# 3. CLI 收到 tool_call 后做什么？

你说得基本对，但我帮你整理成**标准执行流程**：

---

## Step 1：CLI 接收 model 输出

```
LLM → tool_use message → CLI
```

---

## Step 2：Tool Router 判断

```
tool name → 解析 → 判断执行路径
```

可能分三类：

| 类⁠型 | 去⁠哪⁠执⁠行 |
| --- | --- |
| 内⁠置⁠工⁠具 | CLI本⁠地 |
| MCP工⁠具 | MCP Client |
| 普⁠通⁠函⁠数 | 直⁠接⁠调⁠用SDK |

---

## Step 3：如果是 MCP tool → 进入 MCP Client

```
Tool Router → MCP Client
```

---

## Step 4：MCP Client 调 MCP Server

```
CLI → MCP Client → MCP Server
```

---

## Step 5：Server 执行真实动作

例如：

- GitHub API
- DB query
- file system

---

## Step 6：返回结果给 CLI

```json
{
  "issues": [
    { "id": 123, "title": "login crash" }
  ]
}
```

---

# 4. 关键问题：CLI 会不会“再调用 model”？

✔ 会，而且这是 agent 的核心机制

---

## 完整循环是：

```
User
 ↓
LLM（思考）
 ↓
tool_call
 ↓
CLI 执行 MCP tool
 ↓
tool result
 ↓
CLI 再调用 LLM
 ↓
LLM 继续推理
 ↓
最终 answer
```

---

# 5. tool result 是怎么回到 model 的？

✔ 这里是你问的关键点：

> CLI 会把 tool result 包装成 message，再发给 Claude API

---

## 结构如下：

```json
[
  { "role": "user", "content": "查 GitHub bug" },

  {
    "role": "assistant",
    "content": null,
    "tool_use": {
      "name": "mcp__github__search_issue",
      "input": { "query": "login bug" }
    }
  },

  {
    "role": "tool",
    "name": "mcp__github__search_issue",
    "content": {
      "issues": [ ... ]
    }
  }
]
```

---

## 然后 CLI 再发给 model：

```
CLI → Claude API → 新一轮推理
```

---

# 6. MCP / Tool / CLI 三者关系（最重要总结）

## ✔ MCP 是什么？

> 工具调用协议（JSON-RPC 风格）

---

## ✔ MCP Server 是什么？

> 工具执行器（tool runtime）

---

## ✔ MCP Client 是什么？

> 协议客户端（CLI内部模块）

---

## ✔ Tool Router 是什么？

> tool 分发器（决定调用哪个执行系统）

---

## ✔ CLI 是什么？

> Agent runtime（控制整个循环）

---

# 7. 你现在的理解，逐句校准

---

## ❓“Tool Router 是 CLI 模块吗？”

✔ 是

---

## ❓“model 返回 tool_call 告诉 CLI 调工具？”

✔ 完全正确

---

## ❓“tool_call 包含参数？”

✔ 是的（input JSON）

---

## ❓“CLI 调 MCP server 后再包装给 model？”

✔ 是的，这是 agent loop 的核心

---

# 8. 一句话帮你彻底定型

> Model 负责“决定做什么”，CLI 负责“执行什么”，MCP 负责“怎么做”，Tool Router 负责“走哪条路”。

---

# 9. 如果你下一步要深入（建议）

你已经到“架构理解层”了，下一步可以进入更底层：

### ✔ MCP 协议 JSON-RPC 细节

### ✔ tool schema 是如何注入 prompt 的

### ✔ agent loop 为什么必须是 while true

### ✔ Claude Code vs LangChain agent 的本质区别

或者我可以直接带你：

> 🔥 “手写一个最小 Claude Code + MCP agent（Python版）”

这个会让你彻底打通。

---

# 5、既然有了本地的function...

**问题详情：**

既然有了本地的function tool 为什么还要MCP呢? 直接调用本地的function tool不也是一样的吗?

---

这个问题已经进入**MCP存在的真正工程动机层**了，也是很多人从“会用 tool calling”到“理解 MCP”的分水岭。

我直接给你一个结论 + 再拆原因。

---

# 1. 先给结论（非常重要）

> ✔ MCP 不是为了“替代 function tool”
>  ✔ MCP 是为了解决“function tool 在工程扩展性上的瓶颈”

换句话说：

> function tool = 单体内置能力
>  MCP = 外部工具生态系统标准

---

# 2. 本地 function tool vs MCP tool（本质区别）

## ✔ 本地 function tool（传统方式）

```
Model → CLI → function call → 本地代码执行
```

特点：

- tool 是“写死在程序里的”
- 需要重新部署 CLI 才能加工具
- 工具和应用强耦合

---

### 举例：

```python
def search_github(query):
    return requests.get(...)
```

👉 你必须：

- 改 CLI 代码
- 重新发布版本
- 才能新增 tool

---

## ✔ MCP（现代方式）

```
Model → CLI → MCP Client → MCP Server → Tool
```

特点：

- tool 在外部进程
- tool 可动态注册
- tool 可独立部署
- tool 可远程访问

---

# 3. 为什么“本地 function tool 不够用”？

这是 MCP 的核心存在理由。

---

## ❌ 问题1：扩展性差（最关键）

### function tool：

```
加一个工具 = 改 CLI 代码 + 发布新版本
```

### MCP：

```
加一个工具 = 启一个 MCP server
```

✔ 不用改 CLI

---

## ❌ 问题2：工具生态无法独立演进

function tool：

- tool 和 agent 是绑定的

MCP：

- tool 可以独立进化（团队独立开发）

---

## ❌ 问题3：工具无法跨系统复用

function tool：

- 只能给这个 CLI 用

MCP：

- 可以被：
  - Claude Code
  - Cursor
  - 自己的 agent
  - 多个 AI 系统

---

## ❌ 问题4：权限 / 安全隔离差

function tool：

- tool 在 CLI 进程内
- 容易污染 runtime

MCP：

- tool 在独立进程 / 服务
- 可以 sandbox

---

# 4. MCP 的真正定位（非常关键）

MCP 不是“替代 function tool”，而是：

> ✔ function tool 的“分布式版本 + 标准协议层”

---

# 5. 用一句工程类比你就懂了

## function tool：

> ≈ 本地函数调用（monolith）

```
app.py 里面写所有功能
```

---

## MCP：

> ≈ 微服务 + RPC 标准协议

```
tool = 独立 service
agent = client
```

---

# 6. 为什么不能“直接 function tool 就够了”？

我们用一个真实 AI Agent 场景：

---

## 场景：Claude Code 要支持这些工具

- GitHub
- PostgreSQL
- Redis
- Slack
- Notion
- 本地文件系统
- Jenkins
- Jira

---

## ❌ function tool 方案

你要写：

```
20 个 SDK + 20 个 tool function
全部塞进 CLI
```

问题：

- CLI 变成巨型 monolith
- 更新一个 tool = 发版本
- 不同团队无法独立开发

---

## ✔ MCP 方案

你变成：

```
GitHub MCP server
DB MCP server
Slack MCP server
...
```

CLI 只做：

> “统一调用协议”

---

# 7. MCP 的真正价值（核心总结）

## ✔ 1. 解耦（decoupling）

- CLI ≠ tool 实现

---

## ✔ 2. 插件化（plugin system）

- tool 可随时接入/移除

---

## ✔ 3. 分布式（distributed tools）

- tool 可以在远程服务器

---

## ✔ 4. 生态化（ecosystem）

- 不同公司可以写 MCP server

---

# 8. 你之前理解中的关键误区修正

你说：

> “有本地 function tool 为什么还要 MCP？”

### ❌ 误区：

把 MCP 当成“tool 的另一种实现方式”

---

### ✔ 正确理解：

> MCP 是“tool 的标准化外部化协议”

---

# 9. 最终一张结构图帮你定型

```
          ┌──────────────┐
          │   Model      │
          └─────┬────────┘
                tool_call
                    ↓
        ┌────────────────────┐
        │ Claude Code CLI    │
        │  - Tool Router     │
        │  - MCP Client      │
        │  - Function tools  │
        └───────┬────────────┘
                ↓
     ┌──────────────┬──────────────┐
     ↓                              ↓
Function Tool              MCP Client → MCP Server
(local)                    (external tools)
```

---

# 10. 一句话终极总结

> function tool 是“内置能力”，MCP 是“外置工具生态系统标准”，两者不是替代关系，而是规模化后的结构升级。

---

如果你下一步想继续深入，我建议你直接看这两个最关键问题（会彻底打通 MCP）：

1. MCP 为什么用 JSON-RPC，而不是 HTTP function call？
2. MCP server 的生命周期 / 注册机制到底是怎么工作的？

这两个才是 MCP 的“工程核心”。