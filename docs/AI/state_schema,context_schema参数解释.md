``` python
config = {'configurable': {'thread_id':'user_thread_id_001'}}
agent = create_agent(
	model = 'deepseek:deepseek-v4-flash',
	state_schema = CustomAgentState,
	context_schema = CustomAgentContext,
	checkpointer = PostgresSaver,
	config = config
)
state_schema: 全局的的或者session级别的状态管理器，在多轮对话的tool或中间件中传递，更新状态属性字段。配合checkpointer = PostgresSaver实现session级别的短期记忆,记住多轮对话的上下文消息，通过传入config配置thread_id的属性值来实现线程级别(session级别)记忆。

checkpointer = PostgresSaver会将多轮对话的内容存入Postgres数据库中，当用户再次发起对话时将拉起user_thread_id_001的所有对话内容，然后一起发送给大模型；

context_schema: 单轮对话的上下文管理器,只对一次agent.invoke()生效. 单次对话结束后context_schema的上下文失效。
```

- LangChain的长期记忆
``` python
agent = create_agent(
    model,
    system_prompt="你是一个用户信息管理助手。当用户要求保存或查询用户信息时，必须调用相应的工具函数,并且请用中文回答用户问题",
    tools=[get_user_info, save_user_info],
    store=store
)
store=store 
```