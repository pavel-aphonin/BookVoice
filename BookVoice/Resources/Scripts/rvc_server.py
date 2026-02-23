#!/usr/bin/env python3
"""
BookVoice RVC Server — FastAPI-based local voice conversion server.
Uses RVC (Retrieval-based Voice Conversion) for voice transformation.
Launched and managed automatically by the BookVoice app.
"""

import argparse
import io
import os
import tempfile
from pathlib import Path

import uvicorn
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import Response

app = FastAPI(title="BookVoice RVC Server")

_rvc_engine = None
_models_dir = None


class RVCEngine:
    def __init__(self, models_dir: str):
        self.models_dir = Path(models_dir)
        self.model = None
        self.model_path = None

    def load_model(self, model_path: str):
        if self.model_path == model_path and self.model is not None:
            return

        resolved = Path(model_path)
        if not resolved.exists():
            # Try relative to models dir
            resolved = self.models_dir / model_path
        if not resolved.exists():
            raise FileNotFoundError(f"RVC model not found: {model_path}")

        try:
            from rvc_python.infer import RVCInference
            self.model = RVCInference(device="cpu")
            self.model.load_model(str(resolved))
            self.model_path = model_path
        except ImportError:
            raise RuntimeError("rvc-python package not installed. Run: pip install rvc-python")

    def convert(
        self,
        audio_bytes: bytes,
        model_path: str,
        index_rate: float = 0.75,
        filter_radius: int = 3,
        protect_voiceless: float = 0.33,
    ) -> bytes:
        self.load_model(model_path)

        # Write input to temp file
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f_in:
            f_in.write(audio_bytes)
            input_path = f_in.name

        output_path = input_path.replace(".wav", "_converted.wav")

        try:
            self.model.infer_file(
                input_path=input_path,
                output_path=output_path,
                index_rate=index_rate,
                filter_radius=filter_radius,
                protect=protect_voiceless,
            )

            with open(output_path, "rb") as f:
                result = f.read()

            return result
        finally:
            for p in [input_path, output_path]:
                try:
                    os.unlink(p)
                except OSError:
                    pass

    def list_models(self) -> list[str]:
        models = []
        if self.models_dir.exists():
            for f in self.models_dir.iterdir():
                if f.suffix in (".pth", ".pt", ".bin", ".onnx"):
                    models.append(f.name)
        return models


@app.post("/api/convert")
async def convert(
    audio: UploadFile = File(...),
    model: str = Form(...),
    index_rate: float = Form(0.75),
    filter_radius: int = Form(3),
    protect_voiceless: float = Form(0.33),
):
    global _rvc_engine
    if _rvc_engine is None:
        raise HTTPException(status_code=503, detail="RVC engine not initialized")

    try:
        audio_bytes = await audio.read()
        result = _rvc_engine.convert(
            audio_bytes=audio_bytes,
            model_path=model,
            index_rate=index_rate,
            filter_radius=filter_radius,
            protect_voiceless=protect_voiceless,
        )
        return Response(content=result, media_type="audio/wav")
    except FileNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/models")
async def list_models():
    global _rvc_engine
    if _rvc_engine is None:
        return {"models": []}
    return {"models": _rvc_engine.list_models()}


@app.get("/api/health")
async def health():
    return {"status": "ok"}


def main():
    global _rvc_engine, _models_dir

    parser = argparse.ArgumentParser(description="BookVoice RVC Server")
    parser.add_argument("--port", type=int, default=8101)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--models-dir", default="")
    args = parser.parse_args()

    _models_dir = args.models_dir or os.path.expanduser("~/Library/Application Support/BookVoice/Models")
    os.makedirs(_models_dir, exist_ok=True)

    _rvc_engine = RVCEngine(_models_dir)

    print(f"Starting RVC server: port={args.port}", flush=True)
    uvicorn.run(app, host=args.host, port=args.port, log_level="warning")


if __name__ == "__main__":
    main()
