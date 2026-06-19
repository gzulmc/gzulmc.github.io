### resp = agent.invoke(input={"messages":input},config=config) 

``` java
agent.invoke()直接调用模型的返回格式及属性:
{
    'messages': [
        SystemMessage(
            content='用中文沟通',
            additional_kwargs={},
            response_metadata={},
            id='2ae97ee8-638f-4a51-ba09-42ced2eeb3d6'
        ),
        HumanMessage(
            content='Translate: 我爱编程.',
            additional_kwargs={},
            response_metadata={},
            id='46878e57-2b3f-4bbe-a446-9fb0f263c0cc'
        ),
        AIMessage(
            content="J'adore la programmation.",
            additional_kwargs={},
            response_metadata={},
            id='9383ffe3-8cfc-4847-8d06-675637b329c9',
            tool_calls=[],
            invalid_tool_calls=[]
        ),
        HumanMessage(
            content='Translate: I love building applications.',
            additional_kwargs={},
            response_metadata={},
            id='d599aed0-21ff-45f8-829c-b6ff87e7a0a3'
        ),
        AIMessage(
            content='我爱构建应用程序。',
            additional_kwargs={
                'refusal': None,
                'reasoning_content': 'The user wants me to translate "I love building applications" into Chinese. Let me provide the translation.'
            },
            response_metadata={
                'token_usage': {
                    'completion_tokens': 26,
                    'prompt_tokens': 301,
                    'total_tokens': 327,
                    'completion_tokens_details': {
                        'accepted_prediction_tokens': None,
                        'audio_tokens': None,
                        'reasoning_tokens': 21,
                        'rejected_prediction_tokens': None
                    },
                    'prompt_tokens_details': {
                        'audio_tokens': None,
                        'cached_tokens': 256
                    }
                },
                'prompt_cache_hit_tokens': 256,
                'prompt_cache_miss_tokens': 45,
                'model_provider': 'deepseek',
                'model_name': 'deepseek-v4-flash',
                'system_fingerprint': 'fp_8b330d02d0_prod0820_fp8_kvcache_20260402',
                'id': 'b01c599f-7cd9-4a3c-8a03-94d5fdc7bd42',
                'finish_reason': 'stop',
                'logprobs': None
            },
            id='lc_run--019ec18c-6cdc-79a1-ae6c-c32fed5ddca3-0',
            tool_calls=[],
            invalid_tool_calls=[],
            usage_metadata={
                'input_tokens': 301,
                'output_tokens': 26,
                'total_tokens': 327,
                'input_token_details': {
                    'cache_read': 256
                },
                'output_token_details': {
                    'reasoning': 21
                }
            }
        )
    ]
}
```

```python
# stream_mode='values'(默认):用于查看每步状态变化
# stream_mode='messages' :逐字打印流式输出
stream_it = agent.stream(input=input_content,stream_mode='values')
for chunk in stream_it:
这是chunk的返回格式
{
    'model': {
        'messages': [
            AIMessage(
                content='LangChain是一个开源框架，用于构建基于大型语言模型的应用程序，通过链式调用、工具集成和内存管理等模块化设计，简化AI工作流的开发与部署。',
                additional_kwargs={
                    'reasoning_content': '我们要求写一句话介绍LangChain。LangChain是一个用于构建LLM应用的框架，主要特点是链式调用、工具集成、记忆等。一句话需要简洁准确。'
                },
                response_metadata={
                    'finish_reason': 'stop',
                    'model_name': 'deepseek-v4-flash',
                    'system_fingerprint': 'fp_8b330d02d0_prod0820_fp8_kvcache_20260402',
                    'model_provider': 'deepseek'
                },
                id='lc_run--019ed525-4073-78e0-bce4-330f9d4288f3',
                tool_calls=[],
                invalid_tool_calls=[],
                usage_metadata={
                    'input_tokens': 10,
                    'output_tokens': 72,
                    'total_tokens': 82,
                    'input_token_details': {
                        'cache_read': 0
                    },
                    'output_token_details': {
                        'reasoning': 35
                    }
                }
            )
        ]
    }
}
```


