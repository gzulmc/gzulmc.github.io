# LangChain事件流和代理消息学习指南

**Created:** 6/21/2026 7:53:35  
**Updated:** 6/21/2026 8:42:31  
**Exported:** 6/21/2026 8:48:40  
**Link:** [https://claude.ai/chat/008debad-0b28-4b37-b2ac-0abf285f1d35](https://claude.ai/chat/008debad-0b28-4b37-b2ac-0abf285f1d35)  

## User:

> 6/21/2026 7:53:35

https://docs.langchain.com/oss/python/langchain/event-streaming#agent-messages 阅读这篇文档,带我学习,它是什么?解决了什么问题没有它之前是怎么做的有了它之后的变化,以及怎么理解怎么学. 并通过具体的案例一步步的带我理解它的运行流程和底层逻辑, 和掌握它的常规使用方式以及高级使用方式等

## Assistant:

> 6/21/2026 7:55:38

> 构思了全面的中文教程框架与代码对比示例。
>
> - Let me fetch the documentation page first.
> - [Event Streaming - Docs by LangChain (langchain.com)](https://docs.langchain.com/oss/python/langchain/event-streaming#agent-messages)
> - I have the doc content. Now let me also fetch the underlying Streaming page and LangGraph event-streaming page for more context on "before this feature" comparison, since the user wants to understand what problem it solves, what was the situation before, what changed. Let me fetch the streaming page too for comparison, and maybe the LangGraph event-streaming explanation page.
>   
>   Given the user's background (Java/Python dev, learning LangChain, DeepSeek, agent architectures, prefers concrete executable answers over abstract conceptual discussion, communicates in Chinese), I should write a thorough, structured Chinese tutorial covering:
>   1. 是什么 (what is it)
>   2. 解决了什么问题，没有它之前怎么做 (problem before)
>   3. 有了它之后的变化 (after)
>   4. 怎么理解，怎么学
>   5. 具体案例一步步带着理解运行流程和底层逻辑
>   6. 常规用法和高级用法
>   
>   Let me fetch the streaming.md page (lower-level Pregel stream modes) to understand the "before" state - i.e., stream_mode tuples vs stream_events typed projections. This will help explain "没有它之前是怎么做的".
> - [https://docs.langchain.com/oss/python/langchain/streaming (langchain.com)](https://docs.langchain.com/oss/python/langchain/streaming)
> - Now I have a great understanding of both old (stream_mode tuples) and new (stream_events / Event Streaming with typed projections) approaches. Let me now write a comprehensive Chinese tutorial.
>   
>   I'll structure the response:
>   1. 一句话总结：它是什么
>   2. 没有它之前怎么做（stream_mode的痛点）—用代码对比
>   3. 有了它之后的变化（typed projections / run对象）
>   4. 底层逻辑：LangChain agent基于LangGraph，Event Streaming是stream_events(version="v3")，返回一个run对象，提供了多个"投影"(projection)视角而不需要手动判断tuple类型
>   5. 具体案例一步步带你走一遍运行流程 - 用get_weather例子，逐行解释发生了什么
>   6. 常规使用方式：run.messages, message.text, run.tool_calls, run.values, run.output
>   7. 高级用法：message.tool_calls vs run.tool_calls的区别，message.reasoning，run.extensions（自定义transformer投影），多agent场景（虽然没明确提到在这篇文档，但可以提一下stream_events支持sub-agent via metadata 类似）
>   8. 怎么理解/怎么学 - 学习路径建议
>   
>   I should be careful about citations - I fetched two docs, need to cite specific claims with antml:cite. Let me build the response with citations woven in naturally, but since this is a tutorial in Chinese, I need to translate claims into my own words while citing source sentences.
>   
>   Given the docs have sentence indices, let me identify key citable claims:
>   
>   Doc 1 (event-streaming):
>   - "LangChain agents are built on LangGraph, so they support the same Event Streaming model with agent-focused projections for messages, tool calls, state, and custom updates." sentence index 1-X
>   - "For most application and frontend use cases, use Event Streaming through stream_events(..., version="v3"). Event Streaming returns a run object with typed projections, so you can choose the view you need instead of parsing stream-mode tuples."
>   - Table of projections
>   - "run.messages yields ChatModelStream objects. Each message stream exposes .text, .reasoning, .tool_calls, and .output. Sync projections are iterable for live deltas and drainable for final values."
>   …
> - **Done**

# LangChain Event Streaming 学习笔记

我把这篇文档读完了，结合它链接的 Streaming 页面（讲的是"以前"的方式），给你梳理一遍。

## 一句话理解它是什么

Event Streaming 是 LangChain agent（v1.3+）提供的一套**流式输出 API**，调用方式是 `agent.stream_events(input, version="v3")`。它返回一个 `run` 对象，这个对象不是一坨事件元组，而是按"语义"切好的多个**视角（projection）**——你可以选择只看模型文本、只看工具调用、只看状态快照，互不干扰，不用自己写 if/elif 去分流。

LangChain 的 agent 本质上是构建在 LangGraph 之上的一张图（StateGraph），节点之间跳转执行。Event Streaming 就是对 LangGraph 底层事件流的一层"语义化包装"。

## 没有它之前是怎么做的（痛点）

旧的方式是 `agent.stream(input, stream_mode=[...])`，你要先决定监听哪些 `stream_mode`：

- `updates`：每个节点跑完后的状态更新（比如模型生成了带 tool_call 的消息、工具执行完返回了 ToolMessage）
- `messages`：每个 LLM 调用产生的 `(token, metadata)` 元组，是真正的逐字流
- `custom`：你在工具里用 `get_stream_writer()` 手动写的自定义数据

问题在于：

**第一，你必须自己拼。** `messages` 模式吐出来的是碎片化的 token chunk（包括 `tool_call_chunk`），如果你想要"完整的一条消息"，得自己用 `AIMessageChunk` 相加累积，并且通过 `chunk_position == "last"` 判断什么时候拼完了。

**第二，你必须自己分流。** 每次循环拿到的是 `(mode, chunk)`（v1 格式）或者 `{"type": ..., "data": ...}`（v2 格式），你得手写：

```python
if chunk["type"] == "messages":
    token, metadata = chunk["data"]
    ...
elif chunk["type"] == "updates":
    for source, update in chunk["data"].items():
        if source in ("model", "tools"):
            ...
```

**第三，工具调用的"生成阶段"和"执行阶段"混在一起。** 想同时拿到工具调用的参数流、模型最终消息、工具执行结果，往往要同时开 `stream_mode=["messages", "updates", "custom"]` 三种模式一起跑，在一个大循环里靠节点名字（`source`）做区分。

这套机制能用，但心智负担重——你本质上是在手写一个小状态机来"重组"语义。

## 有了它之后的变化

`stream_events(..., version="v3")` 把这套"重组"逻辑收进了框架内部，对外暴露的是已经按语义切好的视角：

| 投影 | 作用 |
|---|---|
| `for event in run` | 最原始的协议级事件，保留精确到达顺序 |
| `run.messages` | 按每次 LLM 调用切分的消息流 |
| `message.text` | 某条消息的文本增量 + 最终文本 |
| `message.reasoning` | 思维链/推理增量（如果模型支持） |
| `message.tool_calls` | 工具调用参数的生成过程（流式 JSON）+ 最终解析结果 |
| `message.output` | 这条消息完成后的完整对象 |
| `message.usage` | token 用量 |
| `run.tool_calls` | 工具**执行**的生命周期（开始、输出增量、最终结果、报错） |
| `run.values` | agent 状态快照 |
| `run.output` | 最终 agent 状态 |
| `run.extensions` | 自定义 transformer 投影（高级扩展点） |

关键变化是：你不再需要自己拼接 token，也不需要靠 `if chunk["type"]` 判断分支——`message.text` 本身就是"这条消息的文本增量序列"，`message.output` 本身就是"这条消息的完整对象"，框架替你做完了重组。

## 底层逻辑：怎么理解 run 对象

可以这样建立心智模型：

LangChain agent 执行时，底层是一个 LangGraph 图在 model 节点和 tools 节点之间反复横跳（这部分你之前研究 LangChain/DeepSeek 工具调用机制时应该已经摸到一点）。这个图在执行过程中，每一步都会往外吐"原始事件"——`for event in run` 拿到的就是这个最底层、按时间顺序排列的事件流，所有更高级的投影都是基于它派生出来的。

`run.messages` 不是一次性返回，而是**惰性的（lazy）**——只有当你真正开始 `for message in run.messages:` 迭代时，agent 才会被驱动执行。每迭代到一次新的 LLM 调用，就会产出一个新的 `ChatModelStream` 对象（也就是 `message`）。这个对象本身又是一组并行的子投影：`.text`、`.reasoning`、`.tool_calls`、`.output`、`.usage`——它们共享同一次 LLM 调用的底层数据，只是按字段切了不同的视角给你。

## 具体案例：一步步走一遍运行流程

用文档里的天气案例，逐步拆解执行顺序：

```python
from langchain.agents import create_agent

def get_weather(city: str) -> str:
    """Get weather for a city."""
    return f"It's always sunny in {city}!"

agent = create_agent(model="gpt-5-nano", tools=[get_weather])

run = agent.stream_events(
    {"messages": [{"role": "user", "content": "What is the weather in SF?"}]},
    version="v3",
)
```

到这一步，`run` 只是一个"句柄"，agent 还没开始真正执行（惰性）。

```python
for message in run.messages:
```

这一行开始驱动执行。第一次进入循环，对应 agent 的**第一次 model 节点调用**：模型读到用户问题"SF 天气如何"，判断需要调用 `get_weather` 工具，于是开始生成一个 tool_call（而不是直接文本）。

```python
    for delta in message.text:
        print(delta, end="", flush=True)
```

由于这条消息主要内容是工具调用参数（JSON），`message.text` 这时基本是空的或很少——文本增量为空说明这条消息不是在"说话"，而是在"决定调用工具"。如果你想看工具调用的生成过程，应该换成 `message.tool_calls`（下面会讲）。

这次 model 调用结束后，LangGraph 内部自动跳转到 **tools 节点**，真正执行 `get_weather("San Francisco")`，产出一条 `ToolMessage`。这一步不会触发你的 `run.messages` 循环（因为它不是 LLM 调用），但你可以通过 `run.tool_calls` 投影单独观察到它。

接着图跳回 **model 节点**，进行**第二次 LLM 调用**：这次模型拿到工具返回的结果，开始生成最终的自然语言回答。`for message in run.messages` 的循环走到第二轮，这次 `message.text` 才会真正一个字一个字地往外吐字。

```python
final_state = run.output
```

整个循环结束后，`run.output` 给你最终的 agent 状态（相当于 `invoke()` 的返回值），包含完整的消息历史。

整个流程的本质：**一次用户提问触发了两次 LLM 调用 + 一次工具执行**，`run.messages` 把这两次 LLM 调用分别作为两个独立的 `message` 对象呈现给你，中间夹的工具执行通过 `run.tool_calls` 单独可见。

## 常规使用方式

打印流式文字 + 拿 token 用量：

```python
run = agent.stream_events(input, version="v3")

for message in run.messages:
    print(f"[{message.node}] ", end="")   # 标明这条消息来自图里的哪个节点
    for delta in message.text:
        print(delta, end="", flush=True)

    full_message = message.output
    if full_message.usage_metadata:
        print(full_message.usage_metadata)
```

`message.node` 在多 agent / 多节点场景特别有用——可以替代旧方式里手动判断 `source` 字符串。

看状态快照和最终结果：

```python
run = agent.stream_events(input, version="v3")

for snapshot in run.values:
    print(snapshot)

final_state = run.output
```

## 高级使用方式

**区分"生成阶段"和"执行阶段"的工具调用**，这是这套 API 里最值得记住的设计点：

```python
run = agent.stream_events(input, version="v3")

for message in run.messages:
    for chunk in message.tool_calls:           # 模型正在"吐"参数 JSON 的过程
        print(f"tool call chunk: {chunk}")
    finalized = message.tool_calls.get()        # 拿到解析完成的最终 tool_calls
    if finalized:
        print(f"finalized tool calls: {finalized}")

for call in run.tool_calls:                     # 工具真正执行的生命周期
    print(f"{call.tool_name}({call.input})")
    for delta in call.output_deltas:            # 如果工具本身支持流式输出
        print(delta, end="", flush=True)
    print(call.output, call.error)              # 最终结果或报错
```

`message.tool_calls` 关心的是"模型在想什么、参数怎么一点点拼出来的"；`run.tool_calls` 关心的是"工具调用之后，真正执行情况如何、有没有报错"。这两者对应的正是旧方式里你必须手动靠节点名字（`model` vs `tools`）区分的两件事，现在框架直接给你拆成两个独立投影。

`run.extensions` 是留给高级用户的扩展点：你可以注册自定义的 transformer，把原始事件流转换成你自己定义的视图（比如只关心某种自定义业务事件），文档没给具体代码，但这是它可扩展性的体现，适合做前端推送协议的定制层。

## 怎么理解、怎么学

建议的学习/验证顺序，每一步都跑一遍代码感受差异，比单纯看文档有效得多：

1. 先把案例里最简单的 `run.messages` + `message.text` 跑通，体会"流"是什么感觉。
2. 把工具加进去，对比同一个 `message` 里 `message.text` 为空、`message.tool_calls` 有内容的情况，理解一条 `message` 不一定是在"说话"。
3. 加一行 `run.tool_calls`，对照着看工具执行和工具调用生成是两个独立的时间线。
4. 回头把这篇文档开头那个 Streaming 页面里 v1 的写法（`stream_mode=["messages","updates"]` + 手动拼 `AIMessageChunk`）跑一遍，再对比 v3 的写法，会更直观地体会到"框架帮你做了什么"。
5. 如果你后续要接前端，再去看 `message.node`（多节点/多 agent 场景区分来源）和 `run.extensions`（自定义协议）。

这套 API 是 LangChain v1.3 才引入的，文档明确建议新项目直接用它，不再推荐手写 `stream_mode` 元组分流的旧写法。如果你想我现在帮你写一个带工具调用、能在终端里实时打印的完整可运行 demo（比如换成你常用的 DeepSeek 模型），可以直接说一声，我给你写出来跑一遍。

## User:

> 6/21/2026 8:28:38

想要

## Assistant:

> 6/21/2026 8:29:51

> 想要补充说明和验证指导。
>
> - User wants a complete runnable demo, using DeepSeek model (based on their memory of using DeepSeek). Let me write a Python script demonstrating Event Streaming with create_agent, tools, and DeepSeek model via langchain. Given their background, they use `uv` for package management, and have connected DeepSeek via Anthropic-compatible API endpoint for Claude Code, but for LangChain itself they probably use langchain_deepseek or OpenAI-compatible interface via init_chat_model with "deepseek:deepseek-chat" or similar provider string.
>   
>   Let me think about how DeepSeek integrates with LangChain. There's langchain-deepseek integration package, or you can use ChatOpenAI with base_url for DeepSeek's OpenAI-compatible API. Let me check current docs to be accurate, since I shouldn't rely on possibly outdated knowledge. Let me check product-self-knowledge skill? No, that's for Anthropic products. But this is about LangChain/DeepSeek integration, which isn't Anthropic product self-knowledge, so I can just search if needed, or rely on web doc already fetched. Let me search briefly for the correct way to set up DeepSeek with langchain init_chat_model, since the user explicitly works with DeepSeek and want accuracy.
>   
>   Actually I recall: langchain has "deepseek" provider integration via `langchain-deepseek` package, model string like "deepseep:deepseek-chat". Let me quickly verify via web search/fetch since this matters for correctness and the user explicitly uses DeepSeek.
> - langchain init_chat_model deepseek provider langchain-deepseek
> - Good, confirmed: `langchain-deepseek` package, `ChatDeepSeek` class, model="deepseek-chat" for tool calling support (deepseek-reasoner does NOT support tool calling). Need DEEPSEEK_API_KEY env var.
>   
>   Now let me write a complete runnable demo using create_agent with ChatDeepSeek model, a tool, and stream_events v3, demonstrating run.messages, message.text, message.tool_calls, run.tool_calls, run.output.
>   
>   Given the user uses `uv` for package management, I'll give pip/uv install instructions.
>   
>   Let me write the script directly inline as a code block since it's short (~60-80 lines) — under 100 lines, so I could just present it as code in chat per <100 lines rule, or maybe create a file. Given file_creation_advice: "code files" trigger; ">10 lines of code → create files". This is a runnable demo script, more than 10 lines, likely should be created as a file. Let me create it as a .py file in /mnt/user-data/outputs and present it, plus explain in chat. Also it's a "script" which is a standalone artifact the user wants to run locally (not just paste into chat) — definitely file-worthy.
>   
>   Let me write the script with:
>   1. tool: get_weather (keep simple, maybe add a second tool for more interesting demo, e.g. get_population) - keep simple, one tool consistent with the docs example for clarity, plus maybe an additional tool to show multiple tool_calls.
>   
>   I'll build it with two tools to make run.tool_calls more interesting (showing multiple parallel tool calls), but maybe keep simple with one tool to match the doc and not overcomplicate. I'll do one main tool (get_weather) and add a quick second decoration for richness — actually let's keep close to the doctrine, single tool, but show full each projection used.
>   
>   Plan for script:
>   - imports: os, from langchain_deepseek import ChatDeepSeek, from langchain.agents import create_agent
>   - tool function get_weather
>   …
> - 创建一个使用 LangChain Event Streaming + DeepSeek 的可运行示例脚本
> - Presenting file(s)...
> - Now I should add a short explanation in chat, including a note that I haven't run it (no DeepSeek API access in this sandbox), instructions, and a note about expected output shape so the user can verify behavior.
> - **Done**

几点说明，跑之前先看一眼：

**安装与运行**

```bash
uv add langchain langchain-deepseek
export DEEPSEEK_API_KEY="sk-你的key"
python event_streaming_deepseek_demo.py
```

**关于这个脚本的设计**

只发起了一次 `agent.stream_events(...)`，在同一个 `run` 上依次走完三个投影,这样能完整看到"一次提问 → 几次 LLM 调用 → 调用了哪些工具 → 最终答案"这条链路,而不是每次演示一个功能就重新调一次 API（既费钱也看不出前后关联）。问题故意设计成需要查两个城市天气 + 比较人口,这样模型大概率会触发多个并行 tool_call,你能在 `run.tool_calls` 那一段看到不止一次工具执行。

**一个我要提前说明的地方**：这个沙盒环境访问不了 DeepSeek 的 API（网络白名单里没有这个域名），所以我没法替你实际跑一遍验证输出。脚本是严格按文档里给出的 API 形状写的（`message.node`、`message.text`、`message.tool_calls.get()`、`run.tool_calls`、`run.output`），但 DeepSeek 模型在工具调用的 chunk 粒度上和 OpenAI/Anthropic 可能略有差异，如果跑起来某个字段为空或报错,大概率是 DeepSeek 返回的 tool_call_chunk 切分方式不一样,把对应那一段换成打印 `message.output` 看完整对象，能更快定位到底是哪个字段不一致。

跑完之后如果输出和预期不一样，把报错或异常输出贴给我，我帮你一起改。

> File: [/mnt/user-data/outputs/event_streaming_deepseek_demo.py](https://claude.ai/api/organizations/737fdee5-04a2-4560-9498-636d26177b24/conversations/008debad-0b28-4b37-b2ac-0abf285f1d35/wiggle/download-file?path=%2Fmnt%2Fuser-data%2Foutputs%2Fevent_streaming_deepseek_demo.py)

---

**Sources:**

- [ChatDeepSeek integration - Docs by LangChain](https://docs.langchain.com/oss/python/integrations/chat/deepseek)
- [ChatDeepSeek | langchain_deepseek | LangChain Reference](https://reference.langchain.com/python/langchain-deepseek/chat_models/ChatDeepSeek)
- [GitHub - SyJarvis/langchain-deepseek: Using the deepseek model in langchain · GitHub](https://github.com/SyJarvis/langchain-deepseek)
- [LangChain Reference Docs](https://python.langchain.com/api_reference/deepseek/chat_models/langchain_deepseek.chat_models.ChatDeepSeek.html)
- [langchain_deepseek | LangChain Reference](https://reference.langchain.com/python/integrations/langchain_deepseek/)
- [langchain/deepseek](https://www.npmjs.com/package/@langchain/deepseek)
- [init_chat_model | langchain | LangChain Reference](https://reference.langchain.com/python/langchain/chat_models/base/init_chat_model)
- [Source code for langchain_deepseek.chat_models](https://python.langchain.com/api_reference/_modules/langchain_deepseek/chat_models.html)
- [ChatDeepSeek — 🦜🔗 LangChain documentation](https://reference.langchain.com/v0.3/python/deepseek/chat_models/langchain_deepseek.chat_models.ChatDeepSeek.html)
- [LangChain - Changelog | DeepSeek integration in LangChain](https://changelog.langchain.com/announcements/deepseek-integration-in-langchain)

## User:

> 6/21/2026 8:41:37

返回的run对象和流式输出agent.stream()返回的流式输出迭代器对象有什么区别?

## Assistant:

> 6/21/2026 8:42:31

> 对比分析了run对象与stream迭代器的结构、消费模式和语义差异。
>
> - The user is asking about the difference between the `run` object returned by `agent.stream_events()` (Event Streaming API) versus the streaming iterator object returned by `agent.stream()` (the older/lower-level Pregel-based streaming API). This is a technical/conceptual question building on our prior discussion.
>   
>   Let me think through this carefully based on what I've read from the two docs (event-streaming.mdx and streaming.mdx).
>   
>   Key differences:
>   
>   1. **What `agent.stream()` returns**: A generator/iterator that yields `StreamPart` dicts (v2 format: `{type, ns, data}`) or `(mode, chunk)` tuples (v1 format). This is a **single flat iterator** — every event you've subscribed to via `stream_mode` comes through this one iterator, interleaved in arrival order. You consume it once, in a single for loop, and have to branch on `chunk["type"]` to figure out what kind of event it is.
>   
>   2. **What `agent.stream_events(..., version="v3")` returns**: A `run` object — NOT a single iterator, but a container/handle that exposes **multiple independent projections** (`run.messages`, `run.values`, `run.tool_calls`, `run.extensions`, plus `for event in run` for raw events). Each projection is itself a separate iterable. You can iterate `run.messages` to drive execution and get message-level chunks; within that, each `message` is itself a `ChatModelStream` object exposing `.text`, `.reasoning`, `.tool_calls`, `.output`, `.usage` — sub-projections of that single message.
>   
>   3. **Underlying relationship**: `run` is built on top of the same underlying LangGraph event protocol that powers `agent.stream()`. The raw event stream is the same substrate; `agent.stream()` exposes it via `stream_mode`-filtered tuples/dicts, while `stream_events()` wraps it in a `run` object that does the semantic parsing/projection job for you. So `run` is a higher-level abstraction over the same underlying events — not a totally different transport.
>   
>   4. …
> - **Done**

两者最核心的区别是：**`agent.stream()` 返回的是一个"单一扁平迭代器"，而 `agent.stream_events()` 返回的 `run` 是一个"多视图容器对象"**。具体拆开说：

## 1. 结构上：一条流 vs 多个独立投影

`agent.stream(input, stream_mode=[...])` 返回的就是一个标准 Python 生成器——你提前声明好要哪些 `stream_mode`，之后所有事件（不管是 token、状态更新还是自定义数据）都混在**同一条流**里按到达顺序吐给你，你只能用一个 `for` 循环去消费它，靠 `chunk["type"]` 做运行时判断来分流。

`run = agent.stream_events(input, version="v3")` 拿到的不是迭代器本身，而是一个对象，这个对象身上挂着多个**互相独立的属性**：`run.messages`、`run.values`、`run.tool_calls`、`run.extensions`，外加一个 `for event in run` 的原始事件视图。每个属性自己才是可迭代对象。你不是被迫处理一条混合流，而是按需选你想看的那个视图。

```python
# stream()：一个循环，里面靠 type 分流
for chunk in agent.stream(input, stream_mode=["messages", "updates"], version="v2"):
    if chunk["type"] == "messages":
        ...
    elif chunk["type"] == "updates":
        ...

# stream_events()：多个独立循环，各看各的
run = agent.stream_events(input, version="v3")
for message in run.messages:
    ...
for call in run.tool_calls:
    ...
final = run.output
```

## 2. 消费方式：一次性单遍 vs 可以分别回看

`agent.stream()` 的生成器是一次性的——遍历完就空了，你能看到什么完全取决于一开始声明的 `stream_mode`，没法"先看一遍文字，再回头单独看一遍工具调用",因为流只过一次。

`run` 对象支持"先驱动一遍执行,再分别看不同侧面"的用法——就像我们上一版 demo 里那样,先用 `for message in run.messages` 把整个 agent 执行驱动完,然后再单独 `for call in run.tool_calls` 去看工具执行细节,最后再取 `run.output`。这意味着 `run` 内部把底层事件做了缓存/回放,而不是像 `stream()` 那样"过了这村没这店"。

## 3. 粒度：裸 chunk vs 已经拼装好的语义对象

`stream()` 给你的是更底层的东西——`stream_mode="messages"` 吐出来的是 `(token, metadata)`，包括散碎的 `tool_call_chunk`，要拼出一条完整消息得自己用 `AIMessageChunk` 相加、自己判断 `chunk_position == "last"`。

`run.messages` 里每个 `message` 本身是一个 `ChatModelStream` 对象，已经按"一次 LLM 调用"的边界切好了；`message.output` 直接给你拼装完成的完整消息，不需要手动 `+=`。

## 4. 类型判断：运行时判断 vs 天然类型安全

`stream()` 不管你订阅几种 `stream_mode`，拿到的容器形状始终是同一种（v1 是 `(mode, chunk)` 元组，v2 是 `{type, ns, data}` 字典），每次都要写 `if chunk["type"] == "xxx"`。

`run` 的每个投影天然只产出一种语义内容——`message.text` 只可能是文本增量，`message.tool_calls` 只可能是工具调用相关数据，不需要判断类型，IDE 类型提示也更准。

## 5. 底层关系：不是两套机制，是同一套协议的两层封装

`run` 上保留了 `for event in run` 这个最原始的逃生舱口，等价于 `stream()` 给你的裸事件流，顺序也完全一致。可以理解成：两者共享同一套 LangGraph 底层事件协议，`stream()` 是直接把这条协议流（按 `stream_mode` 过滤）扔给你；`stream_events()` 是在这条协议流之上又包了一层"语义投影"，自动帮你做了你原本要手写的分类和拼接工作。

简单总结一句话：`agent.stream()` 的返回值回答的是"事件按什么顺序发生"，而 `run` 对象回答的是"我想从哪个角度看这次执行"——前者是流的视角，后者是视图的视角。

Powered by Claude Exporter (https://www.ai-chat-exporter.net)
