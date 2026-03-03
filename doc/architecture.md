# Архитектура BookVoice

## Общая схема

```
┌─────────────────────────────────────────────────────────┐
│                      SwiftUI Views                       │
│  WizardContainerView ← 5 StepViews + Components         │
└──────────────┬───────────────────────────────────────────┘
               │  @Observable binding
┌──────────────▼───────────────────────────────────────────┐
│                     ViewModels                            │
│  WizardVM → ModelSettingsVM, TextUploadVM, VoiceoverVM,  │
│             TimbreChangeVM, PostProcessingVM              │
└──────────────┬───────────────────────────────────────────┘
               │  async/await
┌──────────────▼───────────────────────────────────────────┐
│                   Services (actor)                        │
│  LiveTTSService  LiveRVCService  LiveAudioEngineService   │
│  LiveTextProcessingService  LocalServerManager            │
└──────────────┬───────────────────────────────────────────┘
               │  HTTP (localhost)
┌──────────────▼───────────────────────────────────────────┐
│                  Python FastAPI серверы                    │
│  tts_server.py (:8100)     rvc_server.py (:8101)         │
└──────────────────────────────────────────────────────────┘
```

## Паттерн: MVVM + Service-Oriented + Actor Concurrency

### Почему так

- **MVVM** — стандарт SwiftUI. View подписывается на `@Observable` ViewModel, реактивно обновляется.
- **Service-слой** — бизнес-логика вынесена из ViewModel в протоколы (`TTSService`, `RVCService`, и т.д.). Позволяет подставлять Mock-реализации для SwiftUI Preview.
- **Actor** — все сервисы и `LocalServerManager` оформлены как `actor`, что даёт потокобезопасность без ручных блокировок. Swift 6 strict concurrency.

### Внедрение зависимостей

```swift
// ServiceContainer.swift
enum ServiceContainer {
    static let shared = LiveServiceContainer()
    static let mock  = MockServiceContainer()
}
```

ViewModel-ы получают сервисы через `ServiceContainer.shared`. В Preview используются `mock`-версии с фиктивными данными.

## Хранение данных

**SwiftData** (встроенный в macOS 14+):

```
VoiceoverProject (главная сущность)
├── Поля шага 1: ttsProvider, apiURL, apiPort, apiKey, systemPrompt
├── Поля шага 2: sourceTextBookmark, segmentationStrategy
├── Поля шага 3: ttsModelName, ttsSpeed, ttsPitch, ttsTemperature, ...
├── Поля шага 4: rvcEnabled, rvcModelPath, rvcIndexRate, ...
├── Поля шага 5: outputFormat, metadataTitle, metadataArtist, ...
└── Связи: textSegments → [TextSegment], audioSegments → [AudioSegment]

VoiceProfile
├── name, modelPath, indexRate, filterRadius, protectVoiceless
└── trainingStatus
```

Файлы (аудио, текст, обложки) хранятся через **security-scoped bookmarks** — `Data`-поля в модели, которые позволяют повторно получить доступ к файлу между запусками.

## Структура ViewModels

```
WizardViewModel
├── project: VoiceoverProject         // текущий проект (SwiftData)
├── currentStep: Int                  // 1…5
├── modelSettings: ModelSettingsViewModel
├── textUpload: TextUploadViewModel
├── voiceover: VoiceoverViewModel
├── timbreChange: TimbreChangeViewModel
├── postProcessing: PostProcessingViewModel
└── finalAudioURLs: [URL]            // вычисляемое: из шага 3 или 4
```

`WizardViewModel` создаёт все дочерние VM один раз в `init()`. При переходе между шагами вызывает `prepareStep(n)`, который передаёт данные из предыдущих шагов в следующий. Например:

```swift
case 3: // Переход на шаг «Озвучка»
    voiceover.updateFromProject(project)  // синхронизирует провайдер
    await voiceover.loadModels()          // запрашивает список моделей с сервера
    let segments = await textUpload.allSegments()
    voiceover.prepareSegments(segments)   // готовит сегменты к синтезу
```

## Потоки данных

### Синтез речи (шаг 3)

```
Пользователь → «Озвучить всё»
    → VoiceoverViewModel.synthesizeAll()
        → for segment in segments:
            → LiveTTSService.synthesize(text, options)
                → HTTP POST localhost:8100/api/tts {text, model, speaker, ...}
                    → tts_server.py → SileroEngine / QwenTTSEngine
                    ← WAV bytes
                ← сохранить в tempAudioDirectory
            → segment.status = .completed
            → progress += 1
```

### Конвертация тембра (шаг 4)

```
Пользователь → «Применить RVC»
    → TimbreChangeViewModel.convertAll()
        → for audioURL in voiceoverAudioURLs:
            → LiveRVCService.convert(audioURL, modelPath, params)
                → HTTP POST localhost:8101/api/convert (multipart)
                    → rvc_server.py → RVCEngine
                    ← converted WAV bytes
```

### Экспорт (шаг 5)

```
Пользователь → «Экспортировать»
    → PostProcessingViewModel.export()
        → LiveAudioEngineService.concatenate(audioURLs, outputURL, format)
            → AVAudioFile: чтение фреймов → запись в выходной файл
            → afconvert / lame: конвертация в MP3/FLAC при необходимости
        → LiveAudioEngineService.writeMetadata(title, artist, album, year, cover)
```

## Конкурентность

Все сервисы — это `actor`, что гарантирует последовательный доступ к внутреннему состоянию:

```swift
actor LiveTTSService: TTSService {
    func synthesize(text: String, options: TTSGenerationOptions) async throws -> URL
    func synthesizeBatch(segments: [...], progress: @Sendable (Int) -> Void) async throws -> [URL]
    func cancel() // отмена текущей операции
}
```

`@Sendable` замыкания используются для progress-колбэков из actor-контекста в MainActor UI.

Отмена реализована через `Task.isCancelled` — проверяется перед каждым сегментом в batch-операциях.

## Файловая система

```
~/Library/Application Support/BookVoice/
├── venv/                  # Python virtual environment
│   └── bin/python3        # Python для серверов
├── Scripts/               # Копии серверных скриптов из бандла
│   ├── tts_server.py
│   └── rvc_server.py
├── Models/                # Скачанные TTS/RVC модели
└── TempAudio/             # Временные WAV-файлы синтеза

~/Library/Logs/BookVoice/  # Логи приложения
```

Приложение при каждом запуске копирует скрипты из бандла в `Application Support/Scripts/`, чтобы обновления кода серверов сразу вступали в силу.
