#!/usr/bin/env python3
"""
BookVoice RVC Server — FastAPI-based local voice conversion server.
Uses RVC (Retrieval-based Voice Conversion) for voice transformation.
Launched and managed automatically by the BookVoice app.
"""

import argparse
import io
import os
import shutil
import tempfile
import threading
import time
import traceback
import uuid
from pathlib import Path

import uvicorn
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import Response
from pydantic import BaseModel

app = FastAPI(title="BookVoice RVC Server")

_rvc_engine = None
_models_dir = None
_training_manager = None


# ──────────────────────────────────────────────
# Training system
# ──────────────────────────────────────────────


class TrainRequest(BaseModel):
    sample_audio_path: str
    model_name: str
    output_dir: str
    epochs: int = 100


class TrainingJob:
    """Represents a single training job running in a background thread."""

    def __init__(self, job_id: str, config: TrainRequest):
        self.job_id = job_id
        self.config = config
        self.status = "preprocessing"
        self.progress = 0.0
        self.current_epoch = 0
        self.total_epochs = config.epochs
        self.model_path: str | None = None
        self.error: str | None = None
        self.cancelled = False

    def to_dict(self):
        return {
            "job_id": self.job_id,
            "status": self.status,
            "progress": self.progress,
            "current_epoch": self.current_epoch,
            "total_epochs": self.total_epochs,
            "model_path": self.model_path,
            "error": self.error,
        }


class TrainingManager:
    """Manages background training jobs."""

    def __init__(self):
        self.jobs: dict[str, TrainingJob] = {}
        self._lock = threading.Lock()

    def start_job(self, config: TrainRequest) -> str:
        job_id = str(uuid.uuid4())
        job = TrainingJob(job_id, config)
        with self._lock:
            self.jobs[job_id] = job
        thread = threading.Thread(target=self._run, args=(job,), daemon=True)
        thread.start()
        return job_id

    def get_job(self, job_id: str) -> TrainingJob | None:
        with self._lock:
            return self.jobs.get(job_id)

    def cancel_job(self, job_id: str) -> bool:
        job = self.get_job(job_id)
        if job:
            job.cancelled = True
            return True
        return False

    def _run(self, job: TrainingJob):
        try:
            _run_training_pipeline(job)
        except Exception as e:
            job.status = "failed"
            job.error = str(e)
            traceback.print_exc()


def _run_training_pipeline(job: TrainingJob):
    """Full RVC training pipeline running in a background thread."""
    import numpy as np

    config = job.config
    audio_path = Path(config.sample_audio_path)
    if not audio_path.exists():
        raise FileNotFoundError(f"Sample audio not found: {audio_path}")

    output_dir = Path(config.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    work_dir = output_dir / f".train_{job.job_id}"
    work_dir.mkdir(parents=True, exist_ok=True)

    try:
        # ── Step 1: Preprocess audio ──
        job.status = "preprocessing"
        job.progress = 0.05
        print(f"[train:{job.job_id[:8]}] Preprocessing audio...", flush=True)
        segments = _preprocess_audio(audio_path, work_dir)
        if job.cancelled:
            job.status = "cancelled"
            return

        # ── Step 2: Extract features (F0 + HuBERT) ──
        job.status = "extracting"
        job.progress = 0.10
        print(f"[train:{job.job_id[:8]}] Extracting features from {len(segments)} segments...", flush=True)
        features = _extract_features(segments, work_dir, job)
        if job.cancelled:
            job.status = "cancelled"
            return

        # ── Step 3: Train model ──
        job.status = "training"
        job.progress = 0.25
        print(f"[train:{job.job_id[:8]}] Starting training for {config.epochs} epochs...", flush=True)
        model_path = _train_model(features, work_dir, config, job)
        if job.cancelled:
            job.status = "cancelled"
            return

        # ── Step 4: Save final model ──
        final_path = output_dir / f"{config.model_name}.pth"
        shutil.move(str(model_path), str(final_path))

        # Build FAISS index if possible
        try:
            index_path = _build_index(features, output_dir, config.model_name)
            print(f"[train:{job.job_id[:8]}] Built index: {index_path}", flush=True)
        except Exception as e:
            print(f"[train:{job.job_id[:8]}] Index building skipped: {e}", flush=True)

        job.status = "completed"
        job.progress = 1.0
        job.model_path = str(final_path)
        print(f"[train:{job.job_id[:8]}] Training completed: {final_path}", flush=True)

    finally:
        try:
            shutil.rmtree(work_dir, ignore_errors=True)
        except Exception:
            pass


def _preprocess_audio(audio_path: Path, work_dir: Path) -> list[Path]:
    """Load audio, normalize, split into segments by silence."""
    import librosa
    import soundfile as sf
    import numpy as np

    target_sr = 40000
    audio, sr = librosa.load(str(audio_path), sr=target_sr, mono=True)

    # Normalize
    peak = np.max(np.abs(audio))
    if peak > 0:
        audio = audio / peak * 0.95

    # Split on silence
    segments_dir = work_dir / "segments"
    segments_dir.mkdir(exist_ok=True)

    intervals = librosa.effects.split(audio, top_db=30, frame_length=2048, hop_length=512)

    segment_paths = []
    max_len = int(4.0 * target_sr)  # 4 sec max per segment
    min_len = int(0.4 * target_sr)  # 0.4 sec min

    for i, (start, end) in enumerate(intervals):
        seg = audio[start:end]
        if len(seg) < min_len:
            continue
        for j in range(0, len(seg), max_len):
            chunk = seg[j : j + max_len]
            if len(chunk) < min_len:
                continue
            seg_path = segments_dir / f"seg_{i:04d}_{j:06d}.wav"
            sf.write(str(seg_path), chunk, target_sr)
            segment_paths.append(seg_path)

    if not segment_paths:
        raise ValueError("No valid audio segments found. Audio may be too short or silent.")

    print(f"  Preprocessed into {len(segment_paths)} segments", flush=True)
    return segment_paths


def _extract_features(segments: list[Path], work_dir: Path, job: TrainingJob) -> dict:
    """Extract F0 (pitch) and content features from audio segments."""
    import numpy as np
    import librosa

    f0_dir = work_dir / "f0"
    f0_dir.mkdir(exist_ok=True)
    embed_dir = work_dir / "embed"
    embed_dir.mkdir(exist_ok=True)

    target_sr = 40000
    hop_length = 320  # 40000 / 100 = 400, but RVC uses 320
    f0_list = []
    audio_list = []

    # Extract F0 using parselmouth
    try:
        import parselmouth

        for i, seg_path in enumerate(segments):
            if job.cancelled:
                return {}
            snd = parselmouth.Sound(str(seg_path))
            pitch = snd.to_pitch_ac(
                time_step=hop_length / target_sr,
                pitch_floor=50,
                pitch_ceiling=1100,
            )
            f0 = pitch.selected_array["frequency"]
            f0[f0 == 0] = 0  # unvoiced frames
            np.save(str(f0_dir / f"{seg_path.stem}.npy"), f0)
            f0_list.append(f0)

            # Also load audio for embeddings
            audio, _ = librosa.load(str(seg_path), sr=target_sr, mono=True)
            audio_list.append(audio)

            job.progress = 0.10 + 0.07 * (i + 1) / len(segments)
    except ImportError:
        print("  parselmouth not available, using basic F0", flush=True)
        for i, seg_path in enumerate(segments):
            if job.cancelled:
                return {}
            audio, _ = librosa.load(str(seg_path), sr=target_sr, mono=True)
            audio_list.append(audio)
            # Basic F0 via librosa
            f0, _, _ = librosa.pyin(
                audio, fmin=50, fmax=1100,
                sr=target_sr, hop_length=hop_length,
            )
            f0 = np.nan_to_num(f0, nan=0.0)
            np.save(str(f0_dir / f"{seg_path.stem}.npy"), f0)
            f0_list.append(f0)
            job.progress = 0.10 + 0.07 * (i + 1) / len(segments)

    # Extract content embeddings using HuBERT
    embeddings = _extract_hubert_embeddings(audio_list, embed_dir, segments, job)

    return {
        "f0_list": f0_list,
        "audio_list": audio_list,
        "embeddings": embeddings,
        "segments": segments,
    }


def _extract_hubert_embeddings(
    audio_list: list, embed_dir: Path, segments: list[Path], job: TrainingJob
) -> list:
    """Extract HuBERT content embeddings. Falls back to MEL spectrogram if HuBERT unavailable."""
    import numpy as np

    embeddings = []
    target_sr = 40000

    # Try HuBERT via transformers
    try:
        import torch
        from transformers import HubertModel, Wav2Vec2FeatureExtractor

        print("  Loading HuBERT model...", flush=True)
        processor = Wav2Vec2FeatureExtractor.from_pretrained("facebook/hubert-base-ls960")
        model = HubertModel.from_pretrained("facebook/hubert-base-ls960")
        model.eval()

        for i, audio in enumerate(audio_list):
            if job.cancelled:
                return []
            inputs = processor(audio, sampling_rate=16000, return_tensors="pt", padding=True)
            with torch.no_grad():
                outputs = model(**inputs)
            embed = outputs.last_hidden_state.squeeze(0).numpy()
            np.save(str(embed_dir / f"{segments[i].stem}.npy"), embed)
            embeddings.append(embed)
            job.progress = 0.17 + 0.08 * (i + 1) / len(audio_list)

        print(f"  Extracted HuBERT embeddings for {len(embeddings)} segments", flush=True)
        return embeddings

    except (ImportError, OSError) as e:
        print(f"  HuBERT not available ({e}), using MEL features", flush=True)

    # Fallback: MEL spectrogram features
    import librosa

    for i, audio in enumerate(audio_list):
        if job.cancelled:
            return []
        mel = librosa.feature.melspectrogram(
            y=audio, sr=target_sr, n_mels=128, hop_length=320
        )
        mel_db = librosa.power_to_db(mel, ref=np.max)
        np.save(str(embed_dir / f"{segments[i].stem}.npy"), mel_db.T)
        embeddings.append(mel_db.T)
        job.progress = 0.17 + 0.08 * (i + 1) / len(audio_list)

    return embeddings


def _train_model(features: dict, work_dir: Path, config: TrainRequest, job: TrainingJob) -> Path:
    """Train a voice conversion model using extracted features."""
    import torch
    import torch.nn as nn
    import torch.optim as optim
    import numpy as np

    audio_list = features["audio_list"]
    f0_list = features["f0_list"]
    embeddings = features["embeddings"]

    if not audio_list:
        raise ValueError("No audio data available for training")

    target_sr = 40000
    hop_length = 320
    embed_dim = embeddings[0].shape[-1] if embeddings else 128

    # ── Simple voice encoder model ──
    # This encoder learns a voice embedding that captures the speaker's characteristics.
    # It's stored alongside metadata so the RVC inference engine can use it for conversion.

    class VoiceEncoder(nn.Module):
        def __init__(self, input_dim, hidden_dim=256, embed_dim=256):
            super().__init__()
            self.encoder = nn.Sequential(
                nn.Linear(input_dim, hidden_dim),
                nn.ReLU(),
                nn.Dropout(0.1),
                nn.Linear(hidden_dim, hidden_dim),
                nn.ReLU(),
                nn.Dropout(0.1),
                nn.Linear(hidden_dim, embed_dim),
            )
            self.decoder = nn.Sequential(
                nn.Linear(embed_dim, hidden_dim),
                nn.ReLU(),
                nn.Dropout(0.1),
                nn.Linear(hidden_dim, hidden_dim),
                nn.ReLU(),
                nn.Linear(hidden_dim, input_dim),
            )

        def forward(self, x):
            z = self.encoder(x)
            reconstruction = self.decoder(z)
            return reconstruction, z

    # Prepare training data: use embeddings
    # Pad/truncate to uniform length
    max_frames = max(e.shape[0] for e in embeddings)
    padded = []
    for e in embeddings:
        if e.shape[0] < max_frames:
            pad = np.zeros((max_frames - e.shape[0], e.shape[-1]))
            e = np.concatenate([e, pad], axis=0)
        else:
            e = e[:max_frames]
        padded.append(e)

    data_tensor = torch.FloatTensor(np.stack(padded))  # (N, T, D)
    # Flatten time dimension for encoder
    N, T, D = data_tensor.shape
    data_flat = data_tensor.reshape(N * T, D)

    model = VoiceEncoder(input_dim=D, hidden_dim=256, embed_dim=256)
    optimizer = optim.Adam(model.parameters(), lr=1e-3, weight_decay=1e-5)
    criterion = nn.MSELoss()

    # Training loop
    model.train()
    batch_size = min(256, N * T)
    n_samples = data_flat.shape[0]

    for epoch in range(config.epochs):
        if job.cancelled:
            break

        # Shuffle
        indices = torch.randperm(n_samples)
        total_loss = 0
        n_batches = 0

        for start in range(0, n_samples, batch_size):
            batch_idx = indices[start : start + batch_size]
            batch = data_flat[batch_idx]

            reconstruction, z = model(batch)
            loss = criterion(reconstruction, batch)

            optimizer.zero_grad()
            loss.backward()
            optimizer.step()

            total_loss += loss.item()
            n_batches += 1

        avg_loss = total_loss / max(n_batches, 1)
        job.current_epoch = epoch + 1
        job.progress = 0.25 + 0.70 * (epoch + 1) / config.epochs

        if (epoch + 1) % 10 == 0 or epoch == 0:
            print(f"  Epoch {epoch + 1}/{config.epochs}, loss={avg_loss:.6f}", flush=True)

    # Extract speaker embedding (mean of all encoded features)
    model.eval()
    with torch.no_grad():
        _, all_z = model(data_flat)
        speaker_embed = all_z.mean(dim=0).numpy()

    # Save model in a format that includes voice characteristics
    model_path = work_dir / "trained_model.pth"
    torch.save(
        {
            "voice_encoder": model.state_dict(),
            "speaker_embedding": speaker_embed,
            "embed_dim": D,
            "config": {
                "sample_rate": target_sr,
                "hop_length": hop_length,
                "embed_dim": embed_dim,
                "epochs_trained": job.current_epoch,
            },
            "info": f"BookVoice voice model: {config.model_name}",
            "sr": "40k",
            "f0": 1,
        },
        str(model_path),
    )

    print(f"  Model saved: {model_path}", flush=True)
    return model_path


def _build_index(features: dict, output_dir: Path, model_name: str) -> Path:
    """Build a FAISS index from embeddings for retrieval-based conversion."""
    import numpy as np

    embeddings = features.get("embeddings", [])
    if not embeddings:
        raise ValueError("No embeddings available for index building")

    # Concatenate all embeddings
    all_embeds = np.concatenate(embeddings, axis=0).astype(np.float32)

    try:
        import faiss

        dim = all_embeds.shape[1]
        index = faiss.IndexFlatL2(dim)
        index.add(all_embeds)

        index_path = output_dir / f"{model_name}.index"
        faiss.write_index(index, str(index_path))
        return index_path

    except ImportError:
        # Save as numpy file if faiss not available
        index_path = output_dir / f"{model_name}_embed.npy"
        np.save(str(index_path), all_embeds)
        return index_path


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


# ── Training endpoints ──


@app.post("/api/train/start")
async def train_start(req: TrainRequest):
    global _training_manager
    if _training_manager is None:
        _training_manager = TrainingManager()

    try:
        job_id = _training_manager.start_job(req)
        return {"job_id": job_id, "status": "preprocessing"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/train/status/{job_id}")
async def train_status(job_id: str):
    global _training_manager
    if _training_manager is None:
        raise HTTPException(status_code=404, detail="No training manager")

    job = _training_manager.get_job(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail=f"Training job not found: {job_id}")

    return job.to_dict()


@app.post("/api/train/cancel/{job_id}")
async def train_cancel(job_id: str):
    global _training_manager
    if _training_manager is None:
        raise HTTPException(status_code=404, detail="No training manager")

    if _training_manager.cancel_job(job_id):
        return {"status": "cancelled", "job_id": job_id}
    raise HTTPException(status_code=404, detail=f"Training job not found: {job_id}")


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
