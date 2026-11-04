#!/usr/bin/env python3
"""Loopback HTTP API for Resemble AI Chatterbox Turbo."""
from __future__ import annotations

import io
import os
import wave
from pathlib import Path

import numpy as np
import soundfile as sf
import uvicorn
from chatterbox.tts_turbo import ChatterboxTurboTTS
from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel, Field

DEVICE = os.environ.get("CHATTERBOX_DEVICE", "cuda")
REF = os.environ.get("CHATTERBOX_REF", "/var/lib/chatterbox/ref.wav")
HOST = os.environ.get("CHATTERBOX_HOST", "127.0.0.1")
PORT = int(os.environ.get("CHATTERBOX_PORT", "8084"))

app = FastAPI(title="Chatterbox Turbo")
model: ChatterboxTurboTTS | None = None


class TtsRequest(BaseModel):
    text: str = Field(..., max_length=300)
    audio_prompt_path: str | None = None


@app.on_event("startup")
def _load_model() -> None:
    global model
    model = ChatterboxTurboTTS.from_pretrained(DEVICE)


@app.get("/health")
def health() -> dict:
    return {
        "ok": model is not None,
        "device": DEVICE,
        "model_id": "ResembleAI/chatterbox-turbo",
        "sample_rate_hz": model.sr if model else None,
    }


@app.post("/tts")
def synthesize(req: TtsRequest) -> Response:
    if model is None:
        raise HTTPException(status_code=503, detail="model not loaded")
    prompt = req.audio_prompt_path or REF
    if not Path(prompt).is_file():
        raise HTTPException(status_code=400, detail=f"reference audio missing: {prompt}")
    wav = model.generate(req.text, audio_prompt_path=prompt)
    if wav.dim() > 1:
        wav = wav.squeeze()
    audio = wav.detach().cpu().numpy()
    buf = io.BytesIO()
    sf.write(buf, audio, int(model.sr), format="WAV", subtype="PCM_16")
    return Response(content=buf.getvalue(), media_type="audio/wav")


def main() -> None:
    uvicorn.run(app, host=HOST, port=PORT, log_level="info")


if __name__ == "__main__":
    main()
