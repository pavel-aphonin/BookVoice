#!/usr/bin/env python3
"""
BookVoice LLM Server — FastAPI-based local LLM server.
Uses llama-cpp-python for inference with GGUF models.
Launched and managed automatically by the BookVoice app.
"""

import argparse
import asyncio
import json
import os
import sys
import threading
from pathlib import Path

import uvicorn
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="BookVoice LLM Server")

# Global state
_engine = None
_current_model_path = None
_models_dir = None
_download_lock = threading.Lock()
_download_progress = {"active": False, "progress": 0.0, "filename": ""}


# --- Request/Response models ---

class ChatRequest(BaseModel):
    text: str
    system_prompt: str = ""
    model: str = ""
    temperature: float = 0.2
    max_tokens: int = 512
    top_p: float = 0.9
    top_k: int = 20
    repeat_penalty: float = 1.1


class DownloadRequest(BaseModel):
    repo_id: str
    filename: str
    expected_size_bytes: int = 0  # fallback if HF metadata fails


class DeleteRequest(BaseModel):
    filename: str


# --- Model Management ---

def get_available_models() -> list[str]:
    """List all .gguf model files in the models directory."""
    if not _models_dir or not os.path.isdir(_models_dir):
        return []
    models = []
    for f in sorted(os.listdir(_models_dir)):
        if f.endswith(".gguf"):
            models.append(f)
    return models


def load_model(model_name: str):
    """Load or switch to a GGUF model."""
    global _engine, _current_model_path

    if not _models_dir:
        raise RuntimeError("Models directory not configured")

    model_path = os.path.join(_models_dir, model_name)
    if not os.path.isfile(model_path):
        raise FileNotFoundError(f"Model not found: {model_name}")

    # Already loaded
    if _current_model_path == model_path and _engine is not None:
        return

    # Unload previous model
    if _engine is not None:
        del _engine
        _engine = None
        _current_model_path = None

    print(f"[LLM] Loading model: {model_name}", flush=True)

    from llama_cpp import Llama

    _engine = Llama(
        model_path=model_path,
        n_ctx=8192,
        n_gpu_layers=-1,  # Use Metal (GPU) on Apple Silicon
        verbose=False,
    )
    _current_model_path = model_path
    print(f"[LLM] Model loaded: {model_name}", flush=True)


# --- Endpoints ---

@app.get("/api/health")
async def health():
    return {"status": "ok", "model_loaded": _engine is not None}


@app.get("/api/models")
async def list_models():
    models = get_available_models()
    return {"models": models}


@app.post("/api/chat")
async def chat(request: ChatRequest):
    if not _engine:
        # Try to auto-load a model
        models = get_available_models()
        if request.model:
            # Find matching model
            matches = [m for m in models if request.model in m]
            if matches:
                load_model(matches[0])
            else:
                raise HTTPException(
                    status_code=400,
                    detail=f"Model '{request.model}' not found. Available: {models}"
                )
        elif models:
            load_model(models[0])
        else:
            raise HTTPException(
                status_code=400,
                detail="No models available. Download a model first."
            )

    messages = []
    if request.system_prompt:
        messages.append({"role": "system", "content": request.system_prompt})
    messages.append({"role": "user", "content": request.text})

    try:
        result = _engine.create_chat_completion(
            messages=messages,
            temperature=request.temperature,
            max_tokens=request.max_tokens,
            top_p=request.top_p,
            top_k=request.top_k,
            repeat_penalty=request.repeat_penalty,
        )
        content = result["choices"][0]["message"]["content"]
        return {"content": content}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/download")
async def download_model(request: DownloadRequest):
    global _download_progress

    if _download_lock.locked():
        raise HTTPException(
            status_code=409,
            detail="A download is already in progress"
        )

    # Verify requests library is available
    try:
        import requests as _req  # noqa: F401
    except ImportError as e:
        raise HTTPException(
            status_code=500,
            detail=f"requests library is not installed: {e}",
        )

    # Build the direct HuggingFace download URL
    download_url = (
        f"https://huggingface.co/{request.repo_id}"
        f"/resolve/main/{request.filename}"
    )

    dest_path = os.path.join(_models_dir, request.filename)
    tmp_path = dest_path + ".downloading"
    os.makedirs(_models_dir, exist_ok=True)

    # Check for a partially downloaded temp file (resume support)
    existing_size = 0
    if os.path.isfile(tmp_path):
        existing_size = os.path.getsize(tmp_path)

    # Use client-provided expected size as initial estimate
    total_bytes = request.expected_size_bytes

    # Reset progress state BEFORE starting thread (clear any previous error)
    _download_progress = {
        "active": True,
        "progress": existing_size / total_bytes if total_bytes > 0 else 0.0,
        "downloaded_bytes": existing_size,
        "total_bytes": total_bytes,
        "filename": request.filename,
        "error": "",
    }

    # Run download in background thread to not block the server
    def _do_download():
        global _download_progress
        import requests as req
        import time

        max_retries = 10
        chunk_size = 1024 * 1024  # 1 MB
        read_timeout = 120  # seconds per chunk read

        with _download_lock:
            try:
                nonlocal total_bytes

                for attempt in range(1, max_retries + 1):
                    try:
                        # How much do we already have on disk?
                        resume_from = (
                            os.path.getsize(tmp_path)
                            if os.path.isfile(tmp_path) else 0
                        )

                        headers = {"User-Agent": "BookVoice/1.0"}
                        if resume_from > 0:
                            headers["Range"] = f"bytes={resume_from}-"
                            print(
                                f"[LLM] Resuming download from "
                                f"{resume_from / 1e6:.1f} MB "
                                f"(attempt {attempt}/{max_retries})",
                                flush=True,
                            )
                        else:
                            print(
                                f"[LLM] Downloading {request.filename} "
                                f"from {request.repo_id} "
                                f"(attempt {attempt}/{max_retries})",
                                flush=True,
                            )

                        resp = req.get(
                            download_url,
                            headers=headers,
                            stream=True,
                            timeout=(30, read_timeout),
                            allow_redirects=True,
                        )
                        resp.raise_for_status()

                        # Update total size from server headers
                        if resp.status_code == 206:  # Partial content
                            cr = resp.headers.get("Content-Range", "")
                            if "/" in cr:
                                total_bytes = int(cr.split("/")[-1])
                        elif "Content-Length" in resp.headers:
                            total_bytes = (
                                int(resp.headers["Content-Length"])
                                + resume_from
                            )
                        _download_progress["total_bytes"] = total_bytes

                        downloaded = resume_from
                        mode = "ab" if resume_from > 0 else "wb"

                        with open(tmp_path, mode) as f:
                            for chunk in resp.iter_content(
                                chunk_size=chunk_size,
                            ):
                                if chunk:
                                    f.write(chunk)
                                    downloaded += len(chunk)
                                    if total_bytes > 0:
                                        _download_progress["progress"] = min(
                                            downloaded / total_bytes, 0.99
                                        )
                                    _download_progress[
                                        "downloaded_bytes"
                                    ] = downloaded

                        # If we got here, download completed successfully
                        break

                    except (
                        req.exceptions.ReadTimeout,
                        req.exceptions.ConnectionError,
                        req.exceptions.ChunkedEncodingError,
                    ) as e:
                        print(
                            f"[LLM] Download interrupted: {e} "
                            f"(attempt {attempt}/{max_retries})",
                            flush=True,
                        )
                        if attempt == max_retries:
                            raise RuntimeError(
                                f"Загрузка не удалась после "
                                f"{max_retries} попыток: {e}"
                            )
                        delay = min(5 * attempt, 30)
                        print(
                            f"[LLM] Retrying in {delay}s...",
                            flush=True,
                        )
                        time.sleep(delay)
                        continue

                # Move temp file to final destination
                if os.path.isfile(dest_path):
                    os.remove(dest_path)
                os.rename(tmp_path, dest_path)

                final_size = os.path.getsize(dest_path)
                _download_progress = {
                    "active": False,
                    "progress": 1.0,
                    "downloaded_bytes": final_size,
                    "total_bytes": final_size,
                    "filename": request.filename,
                    "error": "",
                }
                print(
                    f"[LLM] Download complete: {request.filename} "
                    f"({final_size / 1e9:.2f} GB)",
                    flush=True,
                )

                # Clean up any leftover HF cache from previous attempts
                cache_dir = os.path.join(_models_dir, ".cache")
                if os.path.isdir(cache_dir):
                    import shutil
                    shutil.rmtree(cache_dir, ignore_errors=True)
                    print("[LLM] Cleaned up old HF cache", flush=True)

            except Exception as e:
                print(f"[LLM] Download failed: {e}", flush=True)
                import traceback
                traceback.print_exc()
                _download_progress = {
                    "active": False,
                    "progress": 0.0,
                    "downloaded_bytes": 0,
                    "total_bytes": 0,
                    "filename": "",
                    "error": str(e),
                }

    thread = threading.Thread(target=_do_download, daemon=True)
    thread.start()

    return {"status": "downloading", "filename": request.filename}


@app.get("/api/download/status")
async def download_status():
    return _download_progress


@app.post("/api/delete")
async def delete_model(request: DeleteRequest):
    """Delete a model file from the models directory."""
    global _engine, _current_model_path

    if not _models_dir:
        raise HTTPException(status_code=500, detail="Models directory not configured")

    # Sanitize filename (prevent directory traversal)
    filename = os.path.basename(request.filename)
    if not filename.endswith(".gguf"):
        raise HTTPException(status_code=400, detail="Only .gguf files can be deleted")

    model_path = os.path.join(_models_dir, filename)
    if not os.path.isfile(model_path):
        raise HTTPException(status_code=404, detail=f"Model not found: {filename}")

    # Unload model if it's currently loaded
    if _current_model_path == model_path and _engine is not None:
        del _engine
        _engine = None
        _current_model_path = None
        print(f"[LLM] Unloaded model before deletion: {filename}", flush=True)

    try:
        os.remove(model_path)
        print(f"[LLM] Deleted model: {filename}", flush=True)
        return {"status": "deleted", "filename": filename}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete: {e}")


@app.get("/api/models/info")
async def list_models_with_info():
    """List all models with file sizes."""
    if not _models_dir or not os.path.isdir(_models_dir):
        return {"models": []}

    models = []
    for f in sorted(os.listdir(_models_dir)):
        if f.endswith(".gguf"):
            path = os.path.join(_models_dir, f)
            size_bytes = os.path.getsize(path)
            models.append({
                "filename": f,
                "size_bytes": size_bytes,
                "size_gb": round(size_bytes / 1_073_741_824, 2),
                "loaded": _current_model_path == path,
            })
    return {"models": models}


# --- Main ---

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="BookVoice LLM Server")
    parser.add_argument("--port", type=int, default=8200)
    parser.add_argument("--models-dir", type=str, required=True)
    args = parser.parse_args()

    _models_dir = args.models_dir
    os.makedirs(_models_dir, exist_ok=True)

    print(f"[LLM] Starting server on port {args.port}", flush=True)
    print(f"[LLM] Models directory: {_models_dir}", flush=True)

    available = get_available_models()
    if available:
        print(f"[LLM] Available models: {available}", flush=True)
    else:
        print("[LLM] No models found. Use /api/download to get one.", flush=True)

    uvicorn.run(app, host="127.0.0.1", port=args.port, log_level="warning")
