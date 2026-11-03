import os

PROVIDER = os.getenv("LISTENAI_PROVIDER", "ollama")
CLOUD = PROVIDER == "groq"

OLLAMA_URL = os.getenv("LISTENAI_OLLAMA", "http://localhost:11434")
OLLAMA_MODEL = os.getenv("LISTENAI_MODEL", "qwen3:8b")
KEEP_ALIVE = os.getenv("LISTENAI_KEEP_ALIVE", "30m")
WHISPER_SIZE = os.getenv("LISTENAI_WHISPER", "base")

APP_KEY = os.getenv("LISTENAI_APP_KEY", "")

GROQ_URL = "https://api.groq.com/openai/v1"
GROQ_KEY = os.getenv("GROQ_API_KEY", "")
GROQ_MODEL = os.getenv("LISTENAI_GROQ_MODEL", "openai/gpt-oss-120b")
GROQ_WHISPER = os.getenv("LISTENAI_GROQ_WHISPER", "whisper-large-v3-turbo")
