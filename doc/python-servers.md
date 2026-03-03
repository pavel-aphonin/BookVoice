# Python-серверы

BookVoice использует два Python-сервера на базе FastAPI для синтеза речи и конвертации голоса. Серверы запускаются автоматически приложением, работают на `localhost` и не требуют ручной настройки.

## Общая схема

```
BookVoice.app (Swift)
    │
    ├── LocalServerManager (actor)
    │   ├── ensureVenv()          → создаёт ~/Library/.../BookVoice/venv/
    │   ├── installDependencies() → pip install -r requirements_*.txt
    │   ├── startServer(.tts)     → python3 tts_server.py --port 8100
    │   └── startServer(.rvc)     → python3 rvc_server.py --port 8101
    │
    ├── HTTP POST :8100/api/tts   → TTS-сервер → WAV bytes
    └── HTTP POST :8101/api/convert → RVC-сервер → WAV bytes
```

## Жизненный цикл venv

При первом запуске `LocalServerManager` выполняет следующее:

1. **Поиск Python** — ищет совместимую версию (3.12 → 3.11 → 3.13), избегая 3.14 (нет PyTorch):
   ```
   /opt/homebrew/bin/python3.12
   /opt/homebrew/bin/python3.11
   /opt/homebrew/bin/python3.13
   /usr/local/bin/python3.*
   /usr/bin/python3 (fallback)
   ```

2. **Создание venv** — `python3 -m venv ~/Library/Application Support/BookVoice/venv/`

3. **Установка зависимостей** — по файлам `requirements_*.txt` в зависимости от провайдера:

| Файл | Пакеты |
|------|--------|
| `requirements.txt` | fastapi, uvicorn, numpy, python-multipart |
| `requirements_silero.txt` | torch, torchaudio, omegaconf |
| `requirements_kokoro.txt` | kokoro |
| `requirements_qwen.txt` | qwen-tts, torch, torchaudio, soundfile, numpy |
| `requirements_rvc.txt` | rvc-python, torch |

Зависимости устанавливаются **один раз** и кешируются в venv. При смене провайдера доустанавливаются только недостающие пакеты.

## TTS-сервер (tts_server.py)

**Порт:** 8100 (по умолчанию)

### Эндпоинты

#### `POST /api/tts`

Синтезирует текст и возвращает WAV-файл.

**Тело запроса (JSON):**

```json
{
  "text": "Текст для синтеза",
  "model": "v4_ru",
  "speaker": "xenia",
  "speed": 1.0,
  "pitch": 1.0,
  "emotion": "",
  "language": "russian",
  "temperature": 0.9,
  "top_k": 50,
  "top_p": 1.0,
  "repetition_penalty": 1.05,
  "do_sample": true,
  "max_new_tokens": 2048,
  "ref_audio_path": "/path/to/reference.wav",
  "ref_text": "Текст из образца",
  "x_vector_only_mode": false,
  "subtalker_temperature": -1,
  "subtalker_top_k": -1,
  "subtalker_top_p": -1,
  "subtalker_dosample": true
}
```

Числовые параметры со значением `-1` игнорируются, и используется значение модели по умолчанию.

**Ответ:** `audio/wav` — бинарные данные WAV-файла.

#### `GET /api/models`

Возвращает список доступных моделей текущего провайдера.

```json
{ "models": ["v4_ru", "v3_en", "v3_de", "v3_fr"] }
```

#### `GET /api/speakers?model=v4_ru`

Возвращает список голосов для указанной модели.

```json
{ "speakers": ["aidar", "baya", "kseniya", "xenia", "eugene", "random"] }
```

#### `GET /api/health`

Проверка работоспособности.

```json
{ "status": "ok", "provider": "silero" }
```

### Движки TTS

Сервер создаёт один из трёх движков в зависимости от аргумента `--provider`:

| Движок | Provider | Описание |
|--------|----------|----------|
| `SileroEngine` | `silero` | Загрузка .pt-моделей через torch.hub, 48 кГц |
| `KokoroEngine` | `kokoro` | KPipeline, 24 кГц |
| `QwenTTSEngine` | `qwen` | Qwen3TTSModel из HuggingFace, 24 кГц, CPU-only |

### Особенности QwenTTSEngine

- **CPU-only** — MPS (Metal) вызывает крэш PyTorch при операциях с long-тензорами. На Apple Silicon CPU работает быстро благодаря единой памяти.
- **Три метода генерации** в зависимости от типа модели:
  - `generate_custom_voice(text, speaker, language, instruct)` — CustomVoice
  - `generate_voice_design(text, instruct, language)` — VoiceDesign
  - `generate_voice_clone(text, language, ref_audio, ref_text)` — Base
- **Кэширование эмбеддингов** — при клонировании голоса эмбеддинг извлекается из образца один раз и переиспользуется для всех сегментов. Экономит ~30% времени в пакетном синтезе.

### Запуск вручную (для отладки)

```bash
# Активировать venv
source ~/Library/Application\ Support/BookVoice/venv/bin/activate

# Запустить TTS-сервер
python tts_server.py --provider qwen --port 8100

# Тест синтеза
curl -X POST http://localhost:8100/api/tts \
  -H "Content-Type: application/json" \
  -d '{"text": "Привет, мир!", "model": "1.7B-CustomVoice", "speaker": "vivian", "language": "russian"}' \
  --output test.wav
```

## RVC-сервер (rvc_server.py)

**Порт:** 8101 (по умолчанию)

### Эндпоинты

#### `POST /api/convert`

Конвертирует голос в аудиофайле.

**Тело запроса (multipart/form-data):**

| Поле | Тип | Описание |
|------|-----|----------|
| `audio` | file | Входной WAV-файл |
| `model` | string | Путь к RVC-модели (.pth) |
| `index_rate` | float | Степень применения индекса (0.0–1.0) |
| `filter_radius` | int | Радиус медианного фильтра (0–7) |
| `protect` | float | Защита безголосных звуков (0.0–1.0) |

**Ответ:** `audio/wav` — конвертированный WAV.

#### `GET /api/models`

Список моделей в директории `~/Library/Application Support/BookVoice/Models/`.

#### `GET /api/health`

Проверка работоспособности.

## Переменные окружения

`LocalServerManager` устанавливает следующие переменные при запуске серверов:

| Переменная | Значение | Зачем |
|------------|----------|-------|
| `PYTHONUNBUFFERED` | `1` | Мгновенный вывод логов в stdout |
| `VIRTUAL_ENV` | `.../BookVoice/venv` | Указание на venv |
| `PATH` | venv/bin + /opt/homebrew/bin + $PATH | Доступ к Python, SoX и другим утилитам |
| `PYTORCH_ENABLE_MPS_FALLBACK` | `1` | Фолбэк на CPU для неподдерживаемых MPS-операций |

## Управление портами

- Если порт занят (зомби-процесс от предыдущей сессии), `LocalServerManager` убивает процесс: сначала `SIGTERM`, через секунду — `SIGKILL`.
- При смене провайдера старый сервер останавливается, порт освобождается, и запускается новый.
- Таймаут ожидания запуска: 180 секунд для Qwen (тяжёлая загрузка PyTorch + модели), 60 секунд для Silero/Kokoro, 30 секунд для RVC.
