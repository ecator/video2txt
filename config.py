from dotenv import load_dotenv
import os

load_dotenv()

GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY")
if GOOGLE_API_KEY is None:
    raise ValueError("Please set GOOGLE_API_KEY in .env file")

GOOGLE_MODEL = os.getenv("GOOGLE_MODEL", "gemini-2.5-flash")