| 文件                           | 内容                               |
| ---------------------------- | -------------------------------- |
| main.py                      | 主入口、FFmpeg 检测、参数解析、流水线初始化        |
| config/settings.py           | 配置数据类、环境变量加载、验证                  |
| config/**init**.py           | 配置模块导出                           |
| core/base.py                 | 抽象基类：Subtitle、5 个接口定义            |
| core/speech_recognizer.py    | Whisper 语音识别、GPU 检测、本地模型缓存       |
| core/translator.py           | DeepSeek API 翻译、网络错误重试、批次重试      |
| core/tts_engine.py           | Edge TTS 语音合成、发声人映射、工厂函数         |
| core/audio_processor.py      | 音频适配、时间轴构建、音量归一化、静音生成            |
| core/video_processor.py      | GPU 编码器检测、SRT 生成、视频信息、音频替换       |
| core/**init**.py             | 核心模块导出                           |
| pipeline/video_translator.py | 8 步翻译流水线编排                       |
| pipeline/**init**.py         | 流水线模块导出                          |
| utils/logger.py              | 日志配置、格式化、防重复 handler             |
| utils/**init**.py            | 工具模块导出                           |
| audioop_compat.py            | Python 3.13+ audioop 兼容层（PCM 处理） |
| utils/audioop_compat.py      | 同上（utils 副本）                     |

```shell
uv run python -c " import asyncio, edge_tts asyncio.run(edge_tts.Communicate('你好，这是试听测试', voice='zh-CN-YunxiNeural').save('test.mp3'))"
```

说明：voice参数选择如下表

| ShortName                    | 地域  | 性别  | 风格       |
| ---------------------------- | --- | --- | -------- |
| zh-CN-XiaoxiaoNeural         | 普通话 | 女   | 温柔清晰（默认） |
| zh-CN-YunyangNeural          | 普通话 | 男   | 新闻播报风    |
| zh-CN-YunxiNeural            | 普通话 | 男   | 活泼少年     |
| zh-CN-YunjianNeural          | 普通话 | 男   | 沉稳大气     |
| zh-CN-XiaoyiNeural           | 普通话 | 女   | 自然亲切     |
| zh-CN-YunxiaNeural           | 普通话 | 男   | 幽默风趣     |
| zh-TW-HsiaoChenNeural        | 台湾腔 | 女   | 台普女声     |
| zh-TW-HsiaoYuNeural          | 台湾腔 | 女   | 甜美温柔     |
| zh-TW-YunJheNeural           | 台湾腔 | 男   | 台普男声     |
| zh-HK-HiuGaaiNeural          | 粤语  | 女   | 港式女声     |
| zh-HK-WanLungNeural          | 粤语  | 男   | 港式男声     |
| zh-CN-liaoning-XiaobeiNeural | 东北话 | 女   | 东北方言     |