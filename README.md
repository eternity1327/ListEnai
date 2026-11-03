# ListenAI

Record a lecture or meeting on Android, then get an editable transcript, a lesson, and a quiz, using AI running on your own PC.

```
Flutter app  ->  FastAPI  ->  faster-whisper (transcript)
                          ->  Ollama qwen3:8b (lesson, quiz, meeting report, Q&A)
                          ->  SQLite + storage/audio
```

## 1. Run the backend (PowerShell, on your PC)

```powershell
cd listenai\backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements-local.txt
ollama pull qwen3:8b
[Environment]::SetEnvironmentVariable('OLLAMA_FLASH_ATTENTION','1','User')
[Environment]::SetEnvironmentVariable('OLLAMA_KV_CACHE_TYPE','q8_0','User')
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

- Test it: open http://127.0.0.1:8000/docs
- The first transcription downloads the Whisper `base` model (about 150 MB).
- When Windows Firewall asks, allow Python on **Private networks**.
- Find your PC address with `ipconfig` (IPv4 Address, e.g. `192.168.1.10`).

Optional settings (set before `uvicorn`):

| Variable | Default | Example |
|---|---|---|
| `LISTENAI_MODEL` | `qwen3:8b` | `$env:LISTENAI_MODEL="qwen3:4b"` (3x faster, weaker quizzes) |
| `LISTENAI_WHISPER` | `base` | `$env:LISTENAI_WHISPER="small"` (better for Taglish) |
| `LISTENAI_OLLAMA` | `http://localhost:11434` | |
| `LISTENAI_PROVIDER` | `ollama` | `groq` = cloud AI (needs `GROQ_API_KEY`) |
| `LISTENAI_GROQ_MODEL` | `openai/gpt-oss-120b` | |
| `LISTENAI_GROQ_WHISPER` | `whisper-large-v3-turbo` | |
| `LISTENAI_KEEP_ALIVE` | `30m` | How long Ollama keeps the model loaded after a request |

### Quick start (after setup)

```powershell
cd listenai
powershell -ExecutionPolicy Bypass -File start.ps1
```

Add `-Cloud` to use Groq instead of the laptop (needs the `GROQ_API_KEY` user variable).

This links the phone over USB (`adb reverse`) and starts the server. In the app, use `http://127.0.0.1:8000` over USB, or `http://YOUR-PC-IP:8000` over Wi-Fi (allow TCP port 8000 in Windows Firewall).

## 2. Run the app (phone connected by USB)

```powershell
cd listenai\mobile
flutter create --org com.gianopsima --platforms android .
flutter pub get
flutter run
```

`flutter create .` only adds the missing Android files; it keeps the included code and `AndroidManifest.xml` (mic, internet permissions).

In the app, tap the server icon and enter `http://YOUR-PC-IP:8000`. Phone and PC must be on the same Wi-Fi.

## 3. How to use

1. **Record** or **Upload audio**, then name the session.
2. Tap **Transcribe**, fix any mistakes, tap **Save changes**.
3. Tap **Generate**, pick **Lesson** (Beginner / Detailed / Exam) or **Meeting**.
4. Read the report, then **Take quiz**.
5. After the quiz, tap **Retry missed** to practice only the wrong ones.
6. Tap **Flashcards** to review key terms (**Again** puts a card back in the deck).
7. Tap the chat icon to **Ask the lecture**; answers come only from the transcript.

Long recordings work too: transcripts over 4,000 words are split into parts, each part becomes notes, and the lesson is built from those notes. The app shows live progress (e.g. `Transcribing 42%`, `Reading part 2 of 5`).

## Speed (RTX 4060 8 GB, i7-12650H, 16-min lecture)

| Step | Before | After |
|---|---|---|
| Transcribe | 105 s | 36 s |
| Lesson + quiz (qwen3:8b) | 187 s | 93 s |
| Ask (model loaded) | 6-7 s | 5-6 s |

- Whisper runs batched (`BatchedInferencePipeline`, 8 threads).
- Flash attention + q8 KV cache let qwen3:8b fit 100% on the GPU. Restart the Ollama app after setting the variables.
- The model stays loaded for 30 minutes, so only the first request after a break waits about 15 s to load.

## API

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/health` | Server check |
| POST | `/sessions` | Upload audio (`title`, `file`) |
| GET | `/sessions` | List sessions |
| GET | `/sessions/{id}` | Session details |
| POST | `/sessions/{id}/transcribe` | Start transcription |
| PUT | `/sessions/{id}/transcript` | Save transcript edits |
| POST | `/sessions/{id}/generate` | Start lesson/quiz or meeting report |
| POST | `/sessions/{id}/ask` | Ask a question about the transcript |
| GET | `/sessions/{id}/questions` | Saved Ask history |
| DELETE | `/sessions/{id}` | Delete session and audio |

Transcribe and generate run in the background; the app polls the session status.

## Online server (Render free + Supabase free)

1. Supabase: create a project → **Connect** → copy the **Session pooler** URI (IPv4) and put your database password in it.
2. Google Cloud: Google Auth Platform → create an **Android** client (package `com.gianopsima.listenai` + SHA-1) and a **Web** client.
3. Render: **New → Blueprint** → pick this repo (`render.yaml`). Set `GROQ_API_KEY`, `DATABASE_URL`, and `GOOGLE_CLIENT_ID` (the Web client ID).
4. Build the app:

```powershell
flutter build apk --dart-define=SERVER_URL=https://YOUR-SERVICE.onrender.com --dart-define=GOOGLE_CLIENT_ID=YOUR-WEB-CLIENT-ID
```

- The free server sleeps after 15 minutes idle; the first request takes about a minute.
- Supabase free pauses after a week without activity; restore it from the dashboard.
- Users sign in with Google; each user only sees their own sessions. Without `GOOGLE_CLIENT_ID` (laptop) there is no sign-in.
- Audio is deleted from the server after transcription. Transcription starts right after upload.

## Troubleshooting

- **Cannot reach the server**: check the IP, same Wi-Fi, firewall, and that uvicorn uses `--host 0.0.0.0`.
- **Ollama is not running**: start the Ollama app, then retry.
- **"Cannot reach" over USB**: the USB link resets on replug; run `start.ps1` again.
- **`open() got an unexpected keyword argument 'metadata_errors'`**: keep `av==18.1.0` (newer PyAV breaks faster-whisper).
- **Gradle "Unable to establish loopback connection"**: set `JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=C:\Temp` (Windows user name with a space).
- **Android SDK path contains spaces**: point `ANDROID_HOME` to a junction such as `C:\Android\Sdk`.
- **minSdkVersion error on build**: in `android/app/build.gradle.kts` set `minSdk = 24`.

## Before the Play Store

Host the backend online with HTTPS, add user authentication, and remove `android:usesCleartextTraffic="true"`.
