# 概览

基于 LangChain的视频内容分析工具，可以从视频中提取指定内容。

> 目前支持OpenAI和Google Gemini。

做这个工具的最初目的其实是为了批量重命名柯南的视频文件，所以`sample`里面包含了一个批量重命名柯南视频的脚本。

# 功能特点

- 支持多种视频格式
- 支持自定义提示词
- 包含视频预处理功能（裁剪、压缩）

# 配置
创建 `.env` 文件：
```env
GOOGLE_API_KEY=your_api_key_here
GOOGLE_MODEL=gemini-1.5-flash
# 如果使用OpenAI或者兼容API
LLM_PROVIDER="openai"
OPENAI_BASE_URL="https://api.moonshot.cn/v1"
OPENAI_API_KEY="sk-your_api_key_here"
OPENAI_MODEL="kimi-k2.5"
```

# 使用示例

## 基本使用

```powershell
python main.py -f video_path -p prompt_file [-s start] [-e duration] [-w width] [-a]
```

参数说明：
- `-f`: 视频文件路径（必填）
- `-p`: 提示词文件路径（必填）
- `-t`: 温度值
- `-s`: 需要分析的视频开始时间（秒），默认0秒
- `-e`: 需要分析的视频时长（秒），默认300秒
- `-w`: 压缩后的视频宽度，默认640
- `-a`: 是否包含音频

## 示例脚本

批量提取柯南视频里面的标题然后重命名：

```powershell
.\sample\rename-conan-tv.ps1 -FolderPath "你的视频目录"
```

此脚本会自动：
1. 识别符合格式的柯南视频文件
2. 提取视频中的日文标题
3. 按照标准格式重命名文件
    - 重新命名前：`[SBSUB][CONAN][1133][WEBRIP][1080P][AVC_AAC][CHS_JP](8E9F3494).mp4`
    - 重新命名后：`名探偵コナン.TV1133.ベストハズバンド.1080P.AVC_AAC.CHS_JP.mp4`

## 注意事项

- 确保已配置正确的`Google API Key`或者`OpenAI API Key`
  - 如果是OpenAI兼容API，请确保`OPENAI_BASE_URL`配置正确
- 视频预处理会生成临时文件在`temp`目录用于存放截取的视频片段，需要手动清理
- 处理大文件时注意可能的超时
- 不能保证100%准确
- 并不一定比人工节约时间，但是省力
  - 平均准确率：63%
  - 平均一个耗时（截取5分钟）：7分钟
