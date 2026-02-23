#!/usr/bin/env python3
"""
BookVoice TTS Server — FastAPI-based local TTS server.
Supports Silero TTS and Kokoro TTS models.
Launched and managed automatically by the BookVoice app.
"""

import argparse
import io
import json
import os
import sys
import tempfile
import wave
from pathlib import Path

import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel

app = FastAPI(title="BookVoice TTS Server")

# Global state
_tts_engine = None
_current_provider = None
_current_model = None
_models_dir = None


# --- Request/Response models ---

class SynthesizeRequest(BaseModel):
    text: str
    model: str = ""
    speed: float = 1.0
    pitch: float = 1.0
    emotion: str = ""


# --- Silero TTS Engine ---

class SileroEngine:
    def __init__(self, models_dir: str):
        import torch
        self.torch = torch
        self.models_dir = Path(models_dir)
        self.model = None
        self.model_name = None
        self.sample_rate = 48000

    def load_model(self, model_name: str):
        if self.model_name == model_name and self.model is not None:
            return

        model_path = self.models_dir / f"{model_name}.pt"
        if model_path.exists():
            self.model = self.torch.package.PackageImporter(str(model_path)).load_pickle("tts_models", "model")
        else:
            # Download from silero models hub
            self.model, _ = self.torch.hub.load(
                repo_or_dir="snakers4/silero-models",
                model="silero_tts",
                language="ru" if "ru" in model_name else "en",
                speaker=model_name,
            )
        self.model_name = model_name

    def synthesize(self, text: str, model_name: str, speed: float = 1.0, **kwargs) -> bytes:
        self.load_model(model_name)
        audio = self.model.apply_tts(
            text=text,
            sample_rate=self.sample_rate,
            put_accent=True,
            put_yo=True,
        )
        # Convert tensor to WAV bytes
        audio_np = audio.numpy()
        if speed != 1.0:
            try:
                import torchaudio
                audio_tensor = audio.unsqueeze(0)
                effects = [["tempo", str(speed)]]
                audio_tensor, sr = torchaudio.sox_effects.apply_effects_tensor(audio_tensor, self.sample_rate, effects)
                audio_np = audio_tensor.squeeze(0).numpy()
            except Exception:
                pass  # Skip speed adjustment if torchaudio not available

        return self._to_wav(audio_np, self.sample_rate)

    def list_models(self) -> list[str]:
        models = []
        # List local models
        if self.models_dir.exists():
            for f in self.models_dir.iterdir():
                if f.suffix == ".pt":
                    models.append(f.stem)
        # Default available models
        defaults = ["v3_en", "v3_de", "v3_fr", "v4_ru"]
        for d in defaults:
            if d not in models:
                models.append(d)
        return models

    def _to_wav(self, audio_np, sample_rate: int) -> bytes:
        import numpy as np
        buf = io.BytesIO()
        with wave.open(buf, "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(sample_rate)
            audio_int16 = (audio_np * 32767).astype(np.int16)
            wf.writeframes(audio_int16.tobytes())
        return buf.getvalue()


# --- Kokoro TTS Engine ---

class KokoroEngine:
    def __init__(self, models_dir: str):
        self.models_dir = Path(models_dir)
        self.pipeline = None
        self.model_name = None
        self.sample_rate = 24000

    def load_model(self, model_name: str):
        if self.model_name == model_name and self.pipeline is not None:
            return

        try:
            from kokoro import KPipeline
            lang = "a"  # default: American English
            if "ru" in model_name:
                lang = "r"
            elif "fr" in model_name:
                lang = "f"
            elif "ja" in model_name:
                lang = "j"
            self.pipeline = KPipeline(lang_code=lang)
            self.model_name = model_name
        except ImportError:
            raise RuntimeError("Kokoro package not installed. Run: pip install kokoro")

    def synthesize(self, text: str, model_name: str, speed: float = 1.0, **kwargs) -> bytes:
        self.load_model(model_name)
        import numpy as np

        audio_chunks = []
        for _, _, audio in self.pipeline(text, speed=speed):
            if audio is not None:
                audio_chunks.append(audio)

        if not audio_chunks:
            raise RuntimeError("Kokoro produced no audio output")

        full_audio = np.concatenate(audio_chunks)
        return self._to_wav(full_audio, self.sample_rate)

    def list_models(self) -> list[str]:
        return ["kokoro-v1"]

    def _to_wav(self, audio_np, sample_rate: int) -> bytes:
        import numpy as np
        buf = io.BytesIO()
        with wave.open(buf, "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(sample_rate)
            if audio_np.dtype != np.int16:
                audio_np = (audio_np * 32767).astype(np.int16)
            wf.writeframes(audio_np.tobytes())
        return buf.getvalue()


# --- API Endpoints ---

@app.post("/api/tts")
async def synthesize(req: SynthesizeRequest):
    global _tts_engine
    if _tts_engine is None:
        raise HTTPException(status_code=503, detail="TTS engine not initialized")

    try:
        wav_bytes = _tts_engine.synthesize(
            text=req.text,
            model_name=req.model,
            speed=req.speed,
            pitch=req.pitch,
            emotion=req.emotion,
        )
        return Response(content=wav_bytes, media_type="audio/wav")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/models")
async def list_models():
    global _tts_engine
    if _tts_engine is None:
        return {"models": []}
    return {"models": _tts_engine.list_models()}


@app.get("/api/health")
async def health():
    return {"status": "ok", "provider": _current_provider}


# --- Main ---

def create_engine(provider: str, models_dir: str):
    if provider == "silero":
        return SileroEngine(models_dir)
    elif provider == "kokoro":
        return KokoroEngine(models_dir)
    else:
        raise ValueError(f"Unknown provider: {provider}")


def main():
    global _tts_engine, _current_provider, _models_dir

    parser = argparse.ArgumentParser(description="BookVoice TTS Server")
    parser.add_argument("--provider", required=True, choices=["silero", "kokoro"])
    parser.add_argument("--port", type=int, default=8100)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--models-dir", default="")
    args = parser.parse_args()

    _current_provider = args.provider
    _models_dir = args.models_dir or os.path.expanduser("~/Library/Application Support/BookVoice/Models")

    os.makedirs(_models_dir, exist_ok=True)

    _tts_engine = create_engine(args.provider, _models_dir)

    print(f"Starting TTS server: provider={args.provider}, port={args.port}", flush=True)
    uvicorn.run(app, host=args.host, port=args.port, log_level="warning")


if __name__ == "__main__":
    main()
