import config
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_openai import ChatOpenAI
import sys

def get_llm(temperature=0):
    """
    根据配置返回指定的 LLM 实例
    """
    if config.LLM_PROVIDER == "google":
        if not config.GOOGLE_API_KEY:
            print("Error: GOOGLE_API_KEY is not set in .env", file=sys.stderr)
            sys.exit(1)
        return ChatGoogleGenerativeAI(
            model=config.GOOGLE_MODEL,
            api_key=config.GOOGLE_API_KEY,
            temperature=temperature,
        )
    elif config.LLM_PROVIDER == "openai":
        if not config.OPENAI_API_KEY:
            print("Error: OPENAI_API_KEY is not set in .env", file=sys.stderr)
            sys.exit(1)
        return ChatOpenAI(
            model=config.OPENAI_MODEL,
            api_key=config.OPENAI_API_KEY,
            base_url=config.OPENAI_BASE_URL,
            temperature=temperature,
        )
    else:
        print(f"Error: Unsupported LLM provider: {config.LLM_PROVIDER}", file=sys.stderr)
        sys.exit(1)
