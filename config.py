from dotenv import load_dotenv
import os

load_dotenv()

GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY")
GOOGLE_MODEL = os.getenv("GOOGLE_MODEL", "gemini-2.0-flash")

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o")
OPENAI_BASE_URL = os.getenv("OPENAI_BASE_URL","https://api.openai.com/v1")

# Model provider: 'google' or 'openai'
LLM_PROVIDER = os.getenv("LLM_PROVIDER", "google").lower()

if LLM_PROVIDER == "google":
    if not GOOGLE_API_KEY:
        raise ValueError("Please set GOOGLE_API_KEY in .env file")
elif LLM_PROVIDER == "openai":
    if not OPENAI_API_KEY:
        raise ValueError("Please set OPENAI_API_KEY in .env file")
else:
    raise ValueError(f"Unsupported LLM provider: {LLM_PROVIDER}")