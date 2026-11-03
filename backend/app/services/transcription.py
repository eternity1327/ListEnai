import io
import os
import wave
from functools import cache
from pathlib import Path
from threading import Lock

import av

from app import config
from app.services.ai import post

CPU_THREADS = min(8, os.cpu_count() or 4)
BATCH_SIZE = 8
SAMPLE_RATE = 16000
CLOUD_MAX_BYTES = 24 * 1024 * 1024
PIECE_BYTES = SAMPLE_RATE * 2 * 600
lock = Lock()


@cache
def load_model():
    from faster_whisper import BatchedInferencePipeline, WhisperModel

    model = WhisperModel(config.WHISPER_SIZE, device="cpu", compute_type="int8", cpu_threads=CPU_THREADS)
    return BatchedInferencePipeline(model)


def transcribe_local(audio_path, progress):
    with lock:
        segments, info = load_model().transcribe(audio_path, batch_size=BATCH_SIZE)
        lines = []
        for segment in segments:
            lines.append(segment.text.strip())
            percent = min(99, int(segment.end * 100 / max(info.duration, 1)))
            progress(f"Transcribing {percent}%...")
        return "\n".join(lines).strip()


def to_wav(pcm):
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        wav.writeframes(pcm)
    return ("piece.wav", buffer.getvalue())


def pcm_frames(audio_path):
    resampler = av.AudioResampler(format="s16", layout="mono", rate=SAMPLE_RATE)
    with av.open(audio_path) as container:
        for frame in container.decode(audio=0):
            for out in resampler.resample(frame):
                yield out.to_ndarray().tobytes()
    for out in resampler.resample(None):
        yield out.to_ndarray().tobytes()


def cloud_pieces(audio_path):
    path = Path(audio_path)
    if path.stat().st_size <= CLOUD_MAX_BYTES:
        yield (path.name, path.read_bytes())
        return
    buffer = bytearray()
    for pcm in pcm_frames(audio_path):
        buffer += pcm
        if len(buffer) >= PIECE_BYTES:
            yield to_wav(bytes(buffer[:PIECE_BYTES]))
            del buffer[:PIECE_BYTES]
    if buffer:
        yield to_wav(bytes(buffer))


def groq_transcribe(piece):
    data = post(
        f"{config.GROQ_URL}/audio/transcriptions",
        "Cannot reach the speech service.",
        headers={"Authorization": f"Bearer {config.GROQ_KEY}"},
        files={"file": piece},
        data={"model": config.GROQ_WHISPER, "response_format": "json"},
    )
    return data["text"].strip()


def transcribe_cloud(audio_path, progress):
    texts = []
    for number, piece in enumerate(cloud_pieces(audio_path), 1):
        progress(f"Transcribing part {number}...")
        texts.append(groq_transcribe(piece))
    return "\n".join(texts).strip()


def transcribe(audio_path, progress):
    if config.CLOUD:
        return transcribe_cloud(audio_path, progress)
    return transcribe_local(audio_path, progress)
