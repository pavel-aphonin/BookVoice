//
//  PreprocessingPromptBuilder.swift
//  BookVoice
//

import Foundation

enum PreprocessingPromptBuilder {

    static func buildPrompt(
        ttsProvider: TTSProvider,
        options: PreprocessingOptions
    ) -> String {
        var sections: [String] = []

        sections.append(preamble(for: ttsProvider))

        if options.stressMarks {
            sections.append(stressMarksSection())
        }

        if options.emotionMarkup {
            sections.append(emotionSection(for: ttsProvider))
        }

        if options.pauseInsertion {
            sections.append(pauseSection(for: ttsProvider))
        }

        if options.numberExpansion {
            sections.append(numberExpansionSection())
        }

        if options.abbreviationExpansion {
            sections.append(abbreviationExpansionSection())
        }

        if options.audioRephrasing {
            sections.append(rephrasingSection())
        }

        sections.append(intensitySection(options.intensity))
        sections.append(closingRules(for: ttsProvider, options: options))

        return sections.joined(separator: "\n\n")
    }

    // MARK: - Preamble

    private static func preamble(for provider: TTSProvider) -> String {
        let intro = "Ты — ассистент по подготовке текста для синтеза речи (TTS)."

        switch provider {
        case .silero:
            return """
            \(intro) Текст будет озвучен движком Silero TTS.
            Silero НЕ понимает никаких специальных тегов или разметки. \
            Используй только чистый текст с правильной пунктуацией для управления интонацией.
            """

        case .qwenLocal:
            return """
            \(intro) Текст будет озвучен движком Qwen3 TTS (локально).
            Qwen3 TTS поддерживает инструкции в формате [ИНСТРУКЦИЯ] СТРОГО НА АНГЛИЙСКОМ ЯЗЫКЕ \
            перед фразой. Например: [happy] Привет! или [whisper] Тише...
            Допустимые инструкции: happy, sad, angry, fearful, surprised, disgusted, neutral, \
            sarcastic, excited, friendly, whisper, shouting, cheerful, gentle.
            """

        case .qwenCloud:
            return """
            \(intro) Текст будет озвучен через облачный Qwen3 TTS (DashScope API).
            Инструкции по интонации передаются через параметры API, а НЕ в тексте. \
            Поэтому текст должен быть чистым, без специальных тегов.
            """

        case .kokoro:
            return """
            \(intro) Текст будет озвучен движком Kokoro TTS.
            Kokoro поддерживает теги эмоций в формате <emotion type="тип">текст</emotion> \
            и теги пауз <pause duration="0.5s"/>.
            Допустимые типы эмоций: happy, sad, angry, fearful, surprised.
            """

        case .elevenLabs:
            return """
            \(intro) Текст будет озвучен через ElevenLabs TTS.
            ElevenLabs хорошо работает с чистым текстом и выразительной пунктуацией. \
            При необходимости можно использовать SSML-теги: <emphasis>, <prosody>, <break>.
            """

        case .custom:
            return """
            \(intro) Текст будет озвучен через пользовательский TTS API.
            Формат разметки неизвестен. Используй чистый текст с правильной пунктуацией.
            """
        }
    }

    // MARK: - Stress Marks

    private static func stressMarksSection() -> String {
        """
        УДАРЕНИЯ: На словах с неоднозначным ударением поставь знак ударения \
        (комбинирующий акут U+0301) после ударной гласной.
        Примеры: замо́к (не за́мок), больши́е, доро́га.
        НЕ ставь ударения на односложных словах и на словах, где ударение однозначно.
        """
    }

    // MARK: - Emotion

    private static func emotionSection(for provider: TTSProvider) -> String {
        switch provider {
        case .qwenLocal:
            return """
            ЭМОЦИИ И ИНТОНАЦИЯ: Добавляй инструкции НА АНГЛИЙСКОМ в квадратных скобках \
            перед фразой, которая требует особой интонации:
            [happy], [sad], [angry], [whisper], [excited], [gentle], [sarcastic], [fearful], \
            [surprised], [cheerful], [friendly], [shouting]
            Используй инструкции ТОЛЬКО там, где интонация действительно отличается от нейтральной.
            Пример: [whisper] Он подошёл ближе и прошептал... [excited] Это невероятно!
            """

        case .kokoro:
            return """
            ЭМОЦИИ И ИНТОНАЦИЯ: Оборачивай фрагменты текста в теги эмоций:
            <emotion type="happy">текст</emotion>
            <emotion type="sad">текст</emotion>
            <emotion type="angry">текст</emotion>
            <emotion type="fearful">текст</emotion>
            <emotion type="surprised">текст</emotion>
            Используй теги ТОЛЬКО там, где интонация действительно отличается от нейтральной.
            """

        case .elevenLabs:
            return """
            ЭМОЦИИ И ИНТОНАЦИЯ: Используй выразительную пунктуацию для передачи эмоций:
            - Восклицательные знаки для энергичности
            - Многоточие для задумчивости
            - Вопросительные знаки для удивления
            При необходимости: <emphasis>важное слово</emphasis> или \
            <prosody rate="slow" pitch="low">медленная грустная речь</prosody>.
            """

        case .silero, .qwenCloud, .custom:
            return """
            ЭМОЦИИ И ИНТОНАЦИЯ: Передавай эмоции через выразительную пунктуацию:
            - Восклицательные знаки (!) для энергичности и радости
            - Многоточие (...) для задумчивости и грусти
            - Вопросительные знаки (?) для удивления
            - Длинное тире (—) для драматических пауз
            НЕ добавляй никаких тегов, скобок или специальной разметки.
            """
        }
    }

    // MARK: - Pauses

    private static func pauseSection(for provider: TTSProvider) -> String {
        switch provider {
        case .kokoro:
            return """
            ПАУЗЫ: Вставляй тег паузы там, где нужна выразительная пауза:
            <pause duration="0.3s"/> — короткая пауза
            <pause duration="0.5s"/> — средняя пауза
            <pause duration="1.0s"/> — длинная пауза (перед важным моментом)
            Используй паузы перед важным словом, после обращения, в моментах напряжения.
            """

        case .elevenLabs:
            return """
            ПАУЗЫ: Вставляй паузы там, где нужна выразительная пауза:
            - Многоточие «...» для естественной паузы
            - Длинное тире «—» для драматической паузы
            - При необходимости: <break time="500ms"/> для точного управления
            Используй перед важным словом, после обращения, в моментах напряжения.
            """

        case .silero, .qwenLocal, .qwenCloud, .custom:
            return """
            ПАУЗЫ: Добавляй паузы там, где нужна выразительная пауза:
            - Многоточие «...» для естественной паузы
            - Длинное тире «—» для драматической паузы
            Используй перед важным словом, после обращения, в моментах напряжения.
            Пример: «Дорогие друзья... мы собрались здесь не случайно.»
            """
        }
    }

    // MARK: - Number Expansion

    private static func numberExpansionSection() -> String {
        """
        ЧИСЛИТЕЛЬНЫЕ: Записывай числа словами для корректного произношения.
        Примеры: 1943 → «тысяча девятьсот сорок третий», 15 → «пятнадцать», \
        3.14 → «три целых четырнадцать сотых».
        Даты: 25 марта 2024 года → «двадцать пятого марта две тысячи двадцать четвёртого года».
        Номера телефонов, артикулы и коды оставляй как есть.
        """
    }

    // MARK: - Abbreviation Expansion

    private static func abbreviationExpansionSection() -> String {
        """
        АББРЕВИАТУРЫ: Раскрывай распространённые аббревиатуры полностью.
        Примеры: т.д. → «так далее», т.е. → «то есть», и т.п. → «и тому подобное», \
        г. → «год» или «город» (по контексту), в. → «век», \
        км → «километров», кг → «килограммов», млн → «миллионов».
        Если аббревиатура является общеизвестным названием (NASA, ООН, ЕС), оставляй как есть.
        """
    }

    // MARK: - Rephrasing

    private static func rephrasingSection() -> String {
        """
        АДАПТАЦИЯ ДЛЯ АУДИО: Перефразируй конструкции, которые плохо воспринимаются на слух:
        - Длинные причастные обороты → разбей на короткие предложения
        - Скобки с пояснениями → вводные слова или отдельные предложения
        - Сложные перечисления → упрости или разбей
        - Ссылки и URL → убери или замени описанием
        Сохраняй смысл и стиль оригинала. Не упрощай лексику без необходимости.
        """
    }

    // MARK: - Intensity

    private static func intensitySection(_ intensity: PreprocessingIntensity) -> String {
        switch intensity {
        case .minimal:
            return """
            ИНТЕНСИВНОСТЬ: Минимум изменений. Размечай только самые важные и очевидные места. \
            Лучше пропустить, чем добавить лишнее.
            """
        case .moderate:
            return """
            ИНТЕНСИВНОСТЬ: Умеренная разметка. Отмечай заметные моменты, но не переусердствуй. \
            Баланс между естественностью и выразительностью.
            """
        case .maximal:
            return """
            ИНТЕНСИВНОСТЬ: Подробная разметка. Отмечай все места, где интонация, паузы или \
            ударения могут улучшить звучание. Максимальная выразительность.
            """
        }
    }

    // MARK: - Closing Rules

    private static func closingRules(for provider: TTSProvider, options: PreprocessingOptions) -> String {
        var rules: [String] = []

        if !options.audioRephrasing {
            rules.append("Не меняй слова, не перефразируй, не добавляй и не удаляй текст.")
        }

        rules.append("Возвращай ТОЛЬКО обработанный текст, без объяснений и комментариев.")
        rules.append("Сохраняй все знаки препинания оригинала.")

        switch provider {
        case .silero, .qwenCloud, .custom:
            rules.append("НЕ добавляй никаких тегов, скобок или специальной разметки.")
        case .qwenLocal:
            rules.append("Инструкции в квадратных скобках — ТОЛЬКО на английском языке.")
        case .kokoro:
            rules.append("Используй только допустимые теги <emotion> и <pause>.")
        case .elevenLabs:
            rules.append("Минимум SSML-тегов. Приоритет — чистый текст с пунктуацией.")
        }

        return "ВАЖНО:\n" + rules.map { "- \($0)" }.joined(separator: "\n")
    }
}
