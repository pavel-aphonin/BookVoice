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
    speaker: str = ""
    speed: float = 1.0
    pitch: float = 1.0
    emotion: str = ""
    # --- Qwen-specific generation parameters ---
    language: str = ""           # e.g. "russian", "auto"
    temperature: float = -1      # -1 = use model default (0.9)
    top_k: int = -1              # -1 = use model default (50)
    top_p: float = -1            # -1 = use model default (1.0)
    repetition_penalty: float = -1  # -1 = use model default (1.05)
    do_sample: bool = True
    max_new_tokens: int = -1     # -1 = use model default (2048)
    # --- Voice cloning (Qwen Base models) ---
    ref_audio_path: str = ""     # Local filesystem path to reference WAV
    ref_text: str = ""           # Transcript of reference audio
    x_vector_only_mode: bool = False  # Faster but less accurate cloning
    # --- Subtalker parameters (voice cloning only) ---
    subtalker_temperature: float = -1
    subtalker_top_k: int = -1
    subtalker_top_p: float = -1
    subtalker_dosample: bool = True


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

        # Determine speaker: use provided value or pick a sensible default
        speaker = kwargs.get("speaker", "")
        if not speaker:
            if "ru" in model_name:
                speaker = "random"
            elif "en" in model_name:
                speaker = "en_0"
            elif "de" in model_name:
                speaker = "de_0"
            elif "fr" in model_name:
                speaker = "fr_0"
            else:
                speaker = "random"

        audio = self.model.apply_tts(
            text=text,
            speaker=speaker,
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
        defaults = ["v4_ru", "v3_en", "v3_de", "v3_fr"]
        for d in defaults:
            if d not in models:
                models.append(d)
        return models

    def list_speakers(self, model_name: str) -> list[str]:
        """Return available speakers for a given model."""
        speakers_map = {
            "v4_ru": ["aidar", "baya", "kseniya", "xenia", "eugene", "random"],
            "v3_en": [f"en_{i}" for i in range(118)] + ["random"],
            "v3_de": [f"de_{i}" for i in range(5)] + ["random"],
            "v3_fr": [f"fr_{i}" for i in range(5)] + ["random"],
        }
        return speakers_map.get(model_name, ["random"])

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


# --- Qwen3 TTS Engine ---

class QwenTTSEngine:
    """Qwen3 TTS engine supporting CustomVoice, Base, and VoiceDesign model types."""

    # Map short names to HuggingFace model IDs
    MODEL_ID_MAP = {
        "0.6B-Base": "Qwen/Qwen3-TTS-12Hz-0.6B-Base",
        "0.6B-CustomVoice": "Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice",
        "1.7B-Base": "Qwen/Qwen3-TTS-12Hz-1.7B-Base",
        "1.7B-CustomVoice": "Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice",
        "1.7B-VoiceDesign": "Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign",
    }

    def __init__(self, models_dir: str):
        self.models_dir = Path(models_dir)
        self.model = None
        self.model_name = None
        self.sample_rate = 24000
        # Voice clone embedding cache (avoids re-extracting per segment)
        self._cached_clone_prompt = None
        self._cached_clone_ref_path = None

    @staticmethod
    def _model_type(model_name: str) -> str:
        """Determine model type from name: 'custom_voice', 'base', or 'voice_design'."""
        lower = model_name.lower()
        if "customvoice" in lower or "custom_voice" in lower or "custom-voice" in lower:
            return "custom_voice"
        elif "voicedesign" in lower or "voice_design" in lower or "voice-design" in lower:
            return "voice_design"
        elif "base" in lower:
            return "base"
        # Default to custom_voice as the most versatile
        return "custom_voice"

    def load_model(self, model_name: str):
        if self.model_name == model_name and self.model is not None:
            return

        import time as _time

        try:
            from qwen_tts import Qwen3TTSModel
            import torch

            model_id = self.MODEL_ID_MAP.get(model_name, model_name)
            if not model_id.startswith("Qwen/"):
                model_id = f"Qwen/{model_id}"

            # Loading strategy: CPU only.
            # MPS (Metal) crashes during generation with long_long tensor subtraction
            # bug in PyTorch: 'Compute Function(sub_dense_scalar_long_long)' assertion.
            # CPU on Apple Silicon is fast enough thanks to unified memory.
            strategies = ["cpu"]

            last_error = None
            for device_map in strategies:
                try:
                    print(f"[Qwen] Loading model {model_id} with device_map={device_map}...", flush=True)
                    t0 = _time.time()

                    self.model = Qwen3TTSModel.from_pretrained(
                        model_id,
                        device_map=device_map,
                        dtype=torch.float32,
                    )
                    self.model_name = model_name

                    elapsed = _time.time() - t0
                    print(f"[Qwen] Model loaded in {elapsed:.1f}s (device_map={device_map})", flush=True)
                    return  # Success
                except Exception as e:
                    last_error = e
                    print(f"[Qwen] Failed with device_map={device_map}: {e}", flush=True)
                    self.model = None
                    self.model_name = None

            raise RuntimeError(f"Failed to load model {model_id}: {last_error}")
        except ImportError:
            raise RuntimeError("qwen-tts package not installed. Run: pip install qwen-tts")

    def synthesize(self, text: str, model_name: str, speed: float = 1.0, **kwargs) -> bytes:
        self.load_model(model_name)

        emotion = kwargs.get("emotion", "")
        speaker = kwargs.get("speaker", "vivian")
        language = kwargs.get("language", "") or "russian"

        # Build generation kwargs (only pass non-default values)
        gen_kwargs: dict = {}
        temperature = kwargs.get("temperature", -1)
        if temperature > 0:
            gen_kwargs["temperature"] = temperature
        top_k = kwargs.get("top_k", -1)
        if top_k > 0:
            gen_kwargs["top_k"] = top_k
        top_p = kwargs.get("top_p", -1)
        if top_p > 0:
            gen_kwargs["top_p"] = top_p
        rep_penalty = kwargs.get("repetition_penalty", -1)
        if rep_penalty > 0:
            gen_kwargs["repetition_penalty"] = rep_penalty
        do_sample = kwargs.get("do_sample", True)
        gen_kwargs["do_sample"] = do_sample
        max_new_tokens = kwargs.get("max_new_tokens", -1)
        if max_new_tokens > 0:
            gen_kwargs["max_new_tokens"] = max_new_tokens

        # Dispatch to correct generation method based on model type
        model_type = self._model_type(model_name)
        print(f"[Qwen] Using generation method for model_type={model_type}", flush=True)

        if model_type == "custom_voice":
            wavs, sr = self.model.generate_custom_voice(
                text=text,
                language=language,
                speaker=speaker.lower() if speaker else "vivian",
                instruct=emotion if emotion else None,
                **gen_kwargs,
            )
        elif model_type == "voice_design":
            # VoiceDesign generates voice from a text description
            # Use emotion/instruct field as voice description
            voice_desc = emotion if emotion else "A natural, warm female voice speaking clearly"
            wavs, sr = self.model.generate_voice_design(
                text=text,
                instruct=voice_desc,
                language=language,
                **gen_kwargs,
            )
        elif model_type == "base":
            # Base model — voice cloning from reference audio
            ref_audio_path = kwargs.get("ref_audio_path", "")
            ref_text = kwargs.get("ref_text", "")
            x_vector_only = kwargs.get("x_vector_only_mode", False)

            if not ref_audio_path:
                raise RuntimeError(
                    "Base model requires a reference audio file for voice cloning. "
                    "Please select a reference voice file in the app."
                )

            # Reuse cached voice_clone_prompt if same reference audio
            voice_clone_prompt = None
            if (self._cached_clone_prompt is not None
                    and self._cached_clone_ref_path == ref_audio_path):
                voice_clone_prompt = self._cached_clone_prompt
                print(f"[Qwen] Reusing cached voice_clone_prompt", flush=True)
            else:
                # Extract prompt for caching on first call
                try:
                    voice_clone_prompt = self.model.create_voice_clone_prompt(
                        ref_audio=ref_audio_path,
                        ref_text=ref_text if ref_text else None,
                    )
                    self._cached_clone_prompt = voice_clone_prompt
                    self._cached_clone_ref_path = ref_audio_path
                    print(f"[Qwen] Extracted and cached voice_clone_prompt from {ref_audio_path}", flush=True)
                except Exception as e:
                    print(f"[Qwen] Could not pre-extract voice_clone_prompt: {e}", flush=True)
                    # Fallback: let generate_voice_clone extract it internally
                    voice_clone_prompt = None

            clone_kwargs = dict(gen_kwargs)
            if voice_clone_prompt is not None:
                clone_kwargs["voice_clone_prompt"] = voice_clone_prompt
            # Subtalker parameters (controls reference voice embedding generation)
            sub_temp = kwargs.get("subtalker_temperature", -1)
            if sub_temp > 0:
                clone_kwargs["subtalker_temperature"] = sub_temp
            sub_top_k = kwargs.get("subtalker_top_k", -1)
            if sub_top_k > 0:
                clone_kwargs["subtalker_top_k"] = sub_top_k
            sub_top_p = kwargs.get("subtalker_top_p", -1)
            if sub_top_p > 0:
                clone_kwargs["subtalker_top_p"] = sub_top_p
            clone_kwargs["subtalker_dosample"] = kwargs.get("subtalker_dosample", True)

            wavs, sr = self.model.generate_voice_clone(
                text=text,
                language=language,
                ref_audio=ref_audio_path,
                ref_text=ref_text if ref_text else None,
                x_vector_only_mode=x_vector_only,
                **clone_kwargs,
            )

        self.sample_rate = sr
        audio_np = wavs[0]
        if hasattr(audio_np, "numpy"):
            audio_np = audio_np.numpy()

        return self._to_wav(audio_np, sr)

    def list_models(self) -> list[str]:
        return [
            "0.6B-Base",
            "0.6B-CustomVoice",
            "1.7B-Base",
            "1.7B-CustomVoice",
            "1.7B-VoiceDesign",
        ]

    def list_speakers(self, model_name: str = "") -> list[str]:
        """Return available speakers — only for CustomVoice models."""
        mtype = self._model_type(model_name) if model_name else "custom_voice"
        if mtype == "custom_voice":
            return ["aiden", "dylan", "eric", "ono_anna", "ryan", "serena", "sohee", "uncle_fu", "vivian"]
        return []  # Base and VoiceDesign don't use named speakers

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
def synthesize(req: SynthesizeRequest):
    """Synchronous endpoint — FastAPI runs it in a thread pool so the event loop stays free."""
    import time as _time

    global _tts_engine
    if _tts_engine is None:
        raise HTTPException(status_code=503, detail="TTS engine not initialized")

    try:
        text_preview = req.text[:80] + ("..." if len(req.text) > 80 else "")
        print(f"[TTS] Synthesizing: {len(req.text)} chars, model={req.model}, "
              f"speaker={req.speaker}, lang={req.language}", flush=True)
        print(f"[TTS] Text: {text_preview}", flush=True)
        t0 = _time.time()

        wav_bytes = _tts_engine.synthesize(
            text=req.text,
            model_name=req.model,
            speaker=req.speaker,
            speed=req.speed,
            pitch=req.pitch,
            emotion=req.emotion,
            language=req.language,
            temperature=req.temperature,
            top_k=req.top_k,
            top_p=req.top_p,
            repetition_penalty=req.repetition_penalty,
            do_sample=req.do_sample,
            max_new_tokens=req.max_new_tokens,
            ref_audio_path=req.ref_audio_path,
            ref_text=req.ref_text,
            x_vector_only_mode=req.x_vector_only_mode,
            subtalker_temperature=req.subtalker_temperature,
            subtalker_top_k=req.subtalker_top_k,
            subtalker_top_p=req.subtalker_top_p,
            subtalker_dosample=req.subtalker_dosample,
        )
        elapsed = _time.time() - t0
        print(f"[TTS] Done in {elapsed:.1f}s, output={len(wav_bytes)} bytes", flush=True)
        return Response(content=wav_bytes, media_type="audio/wav")
    except Exception as e:
        print(f"[TTS] ERROR: {e}", flush=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/models")
async def list_models():
    global _tts_engine
    if _tts_engine is None:
        return {"models": []}
    return {"models": _tts_engine.list_models()}


@app.get("/api/speakers")
async def list_speakers(model: str = ""):
    global _tts_engine
    if _tts_engine is None:
        return {"speakers": []}
    if hasattr(_tts_engine, "list_speakers"):
        return {"speakers": _tts_engine.list_speakers(model)}
    return {"speakers": []}


@app.get("/api/health")
async def health():
    return {"status": "ok", "provider": _current_provider}


# --- Main ---

def create_engine(provider: str, models_dir: str):
    if provider == "silero":
        return SileroEngine(models_dir)
    elif provider == "kokoro":
        return KokoroEngine(models_dir)
    elif provider == "qwen":
        return QwenTTSEngine(models_dir)
    else:
        raise ValueError(f"Unknown provider: {provider}")


def main():
    global _tts_engine, _current_provider, _models_dir

    parser = argparse.ArgumentParser(description="BookVoice TTS Server")
    parser.add_argument("--provider", required=True, choices=["silero", "kokoro", "qwen"])
    parser.add_argument("--port", type=int, default=8100)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--models-dir", default="")
    args = parser.parse_args()

    _current_provider = args.provider
    _models_dir = args.models_dir or os.path.expanduser("~/Library/Application Support/BookVoice/Models")

    os.makedirs(_models_dir, exist_ok=True)

    _tts_engine = create_engine(args.provider, _models_dir)

    print(f"Starting TTS server: provider={args.provider}, port={args.port}", flush=True)
    uvicorn.run(
        app,
        host=args.host,
        port=args.port,
        log_level="info",
        timeout_keep_alive=600,  # keep connections alive during long model loads
    )


if __name__ == "__main__":
    main()
