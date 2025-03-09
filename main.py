from langchain_core.globals import set_debug
import os
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.messages import HumanMessage, SystemMessage
from langchain_core.output_parsers import PydanticOutputParser
from langchain_core.prompts import ChatPromptTemplate
from moviepy import VideoFileClip
from langchain_core.output_parsers import StrOutputParser
import base64
import argparse
import sys
import config
import contextlib
import io
from pydantic import BaseModel, Field

set_debug(False)
tempdir = os.path.join(os.path.dirname(__file__), "temp")


@contextlib.contextmanager
def suppress_output(suppress_stdout=True, suppress_stderr=True):
    """临时抑制输出的上下文管理器"""
    stdout = sys.stdout
    stderr = sys.stderr
    output = io.StringIO()
    if suppress_stdout:
        sys.stdout = output
    if suppress_stderr:
        sys.stderr = output
    try:
        yield output
    finally:
        sys.stdout = stdout
        sys.stderr = stderr


def split_file_path(file_path):
    """
    将文件路径拆分为各个组成部分

    Args:
        file_path (str): 完整的文件路径

    Returns:
        tuple: (目录, 纯文件名, 扩展名)
    """
    # 获取目录和完整文件名
    directory = os.path.dirname(file_path)
    filename = os.path.basename(file_path)

    # 分离文件名和扩展名
    name, ext = os.path.splitext(filename)

    return directory, name, ext


def extract_video_segment(
    video_path, audio=False, start_second=0, duration_seconds=30, width=640
):
    """
    提取视频的前N秒
    Args:
        video_path: 视频文件路径
        audio: 是否包含声音
        start_second: 截取视频的开始时间(秒)
        duration_seconds: 需要提取的视频长度(秒)
        width: 截取后视频的宽度（高度等比例缩放）
    Returns:
        bytes: 截取后的视频数据
    """
    video_dir, video_name, video_ext = split_file_path(video_path)
    os.makedirs(tempdir, exist_ok=True)
    temp_path = os.path.join(
        tempdir, f"{video_name}_{width}_{start_second}_{duration_seconds}.webm"
    )

    if not os.path.exists(temp_path):
        # 裁剪视频
        with suppress_output():
            video = VideoFileClip(video_path)
            # 如果视频长度小于指定时长，就用整个视频
            actual_start = min(start_second, video.duration)
            actual_end = min(actual_start + duration_seconds, video.duration)
            # 视频宽度取最小的
            width = min(width, video.size[0])
            video_segment = video.subclipped(start_second, actual_end).resized(
                width=width
            )
        with suppress_output(suppress_stderr=False):
            video_segment.write_videofile(
                temp_path,
                codec="libvpx",
                audio_bitrate="50k",
                audio=audio,
                ffmpeg_params=["-crf", "50"],
            )
        video_segment.close()
        video.close()
    else:
        print(f"{temp_path} already exists. Skip", file=sys.stderr, flush=True)

    # 读取临时文件
    with open(temp_path, "rb") as f:
        video_data = f.read()

    return video_data


class LLMResponse(BaseModel):
    """
    AI回答
    """
    result: str = Field(description="The result of the AI response")


def ask_ai(video_data, prompt, temperature=0) -> LLMResponse:
    """
    向AI提问
    Args:
        video_data: 视频数据
        prompt: 提示词
        temperature: 温度值
    Returns:
        str: AI的回答
    """
    # 文件MIME类型
    mime_type = "video/webm"

    # 初始化 LLM
    llm = ChatGoogleGenerativeAI(
        model=config.GOOGLE_MODEL,
        api_key=config.GOOGLE_API_KEY,
        temperature=temperature,
    )
    video_b64 = base64.b64encode(video_data).decode("utf-8")
    # 构建消息
    prompts = ChatPromptTemplate.from_messages(
        [
            SystemMessage(
                "Please respond to the user using JSON format and place the result in the `result` field"
            ),
            HumanMessage(
                content=[
                    {
                        "type": "text",
                        "text": prompt,
                    },
                    {"type": "media", "mime_type": mime_type, "data": video_b64},
                ]
            ),
        ]
    )
    chain = prompts | llm.with_structured_output(LLMResponse)
    print(f"Asking {config.GOOGLE_MODEL}...", file=sys.stderr, flush=True)
    response = chain.invoke({})

    return response


def main():
    """
    主函数
    """
    parser = argparse.ArgumentParser(description="解析视频文件输出文本")
    parser.add_argument("-f", required=True, type=str, help="视频文件路径")
    parser.add_argument("-s", type=int, default=0, help="视频截取的开始时间(秒)")
    parser.add_argument("-e", type=int, default=300, help="视频截取的长度(秒)")
    parser.add_argument("-a", action="store_true", help="是否包含声音")
    parser.add_argument(
        "-w", type=int, default=640, help="压缩后视频的宽度（高度会等比例缩放）"
    )
    parser.add_argument(
        "-p", type=str, required=True, help="提交给AI的提示词路径，注意只支持utf8编码"
    )
    parser.add_argument(
        "-t", type=float, default=0, help="温度参数，0-1之间，越大越随机"
    )
    args = parser.parse_args()
    video_path = args.f
    start_second = args.s
    duration_seconds = args.e
    audio = args.a
    width = args.w
    prompt_file = args.p
    temperature = args.t
    if not os.path.exists(prompt_file):
        print(f"文件不存在: {prompt_file}")
        sys.exit(1)
    with open(prompt_file, "r", encoding="utf-8") as f:
        prompt = f.read()
    print(f"model: {config.GOOGLE_MODEL}", file=sys.stderr, flush=True)
    print(f"video_path: {video_path}", file=sys.stderr, flush=True)
    print(f"audio: {audio}", file=sys.stderr, flush=True)
    print(f"start_second: {start_second}", file=sys.stderr, flush=True)
    print(f"duration_seconds: {duration_seconds}", file=sys.stderr, flush=True)
    print(f"temperature: {temperature}", file=sys.stderr, flush=True)
    print(f"prompt: {prompt}", file=sys.stderr, flush=True)

    # 截取视频文件
    video_data = extract_video_segment(
        video_path=video_path,
        audio=audio,
        start_second=start_second,
        duration_seconds=duration_seconds,
        width=width,
    )

    response = ask_ai(video_data, prompt, temperature)
    print(response.result, file=sys.stdout)


if __name__ == "__main__":
    main()
