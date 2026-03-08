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

        sections.append(coreRules())
        sections.append(taskDescription(for: ttsProvider))

        if options.emotionMarkup {
            sections.append(emotionSection(for: ttsProvider))
        }

        if options.pauseInsertion {
            sections.append(pauseSection(for: ttsProvider))
        }

        if options.stressMarks {
            sections.append(stressMarksSection())
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
        sections.append(examples(for: ttsProvider, options: options))

        return sections.joined(separator: "\n\n")
    }

    // MARK: - Core Rules (anti-translation, anti-markdown, output format)

    private static func coreRules() -> String {
        """
        СТРОГИЕ ПРАВИЛА (нарушение недопустимо):
        1. НЕ ПЕРЕВОДИ текст. Язык текста ВСЕГДА остаётся оригинальным. Русский текст → русский текст.
        2. НЕ используй markdown (**, ##, __, `` и т.д.). Никакого форматирования.
        3. Выводи ТОЛЬКО обработанный текст. Без приветствий, пояснений, комментариев, нумерации.
        4. НЕ добавляй и НЕ удаляй слова из оригинала (кроме случаев, указанных ниже).
        5. Сохраняй ВСЕ знаки препинания оригинала.
        """
    }

    // MARK: - Task Description

    private static func taskDescription(for provider: TTSProvider) -> String {
        switch provider {
        case .silero:
            return """
            ЗАДАЧА: Подготовь текст для синтеза речи движком Silero TTS.
            Silero НЕ понимает тегов и разметки. Только чистый текст с пунктуацией.
            НЕ добавляй квадратных скобок, угловых скобок или другой разметки.
            """

        case .qwenLocal:
            return """
            ЗАДАЧА: Подготовь текст для синтеза речи движком Qwen TTS.
            Qwen TTS понимает теги эмоций в формате [тег] перед фразой.
            Теги пишутся на английском: [happy], [sad], [angry], [whisper] и др.
            Сам текст фразы остаётся НА ЯЗЫКЕ ОРИГИНАЛА, без перевода.
            """

        case .qwenCloud:
            return """
            ЗАДАЧА: Подготовь текст для синтеза речи через Qwen Cloud API.
            Эмоции задаются через API, а НЕ в тексте. Текст должен быть чистым.
            НЕ добавляй квадратных скобок, угловых скобок или другой разметки.
            """

        case .kokoro:
            return """
            ЗАДАЧА: Подготовь текст для синтеза речи движком Kokoro TTS.
            Kokoro понимает теги: <emotion type="тип">текст</emotion> и <pause duration="Xs"/>.
            Типы эмоций: happy, sad, angry, fearful, surprised.
            """

        case .elevenLabs:
            return """
            ЗАДАЧА: Подготовь текст для синтеза речи через ElevenLabs.
            ElevenLabs работает с чистым текстом и выразительной пунктуацией.
            Можно использовать SSML: <emphasis>, <prosody>, <break>.
            """

        case .custom:
            return """
            ЗАДАЧА: Подготовь текст для синтеза речи.
            Используй чистый текст с правильной пунктуацией. Без специальной разметки.
            """
        }
    }

    // MARK: - Emotion

    private static func emotionSection(for provider: TTSProvider) -> String {
        switch provider {
        case .qwenLocal:
            return """
            ЭМОЦИИ: Ставь тег перед фразой ТОЛЬКО если эмоция ярко выражена в тексте.
            Допустимые теги (и ТОЛЬКО они): [happy] [sad] [angry] [whisper] [excited] [gentle] [shouting] [friendly] [fearful] [surprised]
            Формат: [тег] текст фразы. Без звёздочек, кавычек, markdown.
            НЕЛЬЗЯ придумывать свои теги. НЕЛЬЗЯ использовать [nasty], [A], [neutral] или другие — только из списка выше.
            Большинство фраз НЕ нужно размечать. Оставляй без тега, если эмоция не очевидна.
            """

        case .kokoro:
            return """
            ЭМОЦИИ: Оборачивай эмоциональные фрагменты в теги:
            <emotion type="happy">текст</emotion>
            Типы: happy, sad, angry, fearful, surprised.
            Только где эмоция явно отличается от нейтральной.
            """

        case .elevenLabs:
            return """
            ЭМОЦИИ: Передавай эмоции пунктуацией:
            ! — энергичность, ... — задумчивость, ? — удивление.
            Если нужно: <emphasis>слово</emphasis> или <prosody rate="slow">речь</prosody>.
            """

        case .silero, .qwenCloud, .custom:
            return """
            ЭМОЦИИ: Передавай эмоции только через пунктуацию:
            ! — энергичность и радость, ... — задумчивость, ? — удивление, — — пауза.
            Никаких тегов, скобок или разметки.
            """
        }
    }

    // MARK: - Pauses

    private static func pauseSection(for provider: TTSProvider) -> String {
        switch provider {
        case .kokoro:
            return """
            ПАУЗЫ: <pause duration="0.3s"/> — короткая, <pause duration="0.5s"/> — средняя, <pause duration="1.0s"/> — длинная.
            """

        case .elevenLabs:
            return """
            ПАУЗЫ: ... — пауза, — — драматическая пауза, <break time="500ms"/> — точная пауза.
            """

        case .silero, .qwenLocal, .qwenCloud, .custom:
            return """
            ПАУЗЫ: ... — пауза, — — драматическая пауза. Перед важным словом, после обращений.
            """
        }
    }

    // MARK: - Stress Marks

    private static func stressMarksSection() -> String {
        """
        УДАРЕНИЯ: На словах с неоднозначным ударением ставь знак ударения (U+0301) после ударной гласной.
        Пример: замо́к, больши́е. Не ставь на односложных словах.
        """
    }

    // MARK: - Number Expansion

    private static func numberExpansionSection() -> String {
        """
        ЧИСЛА: Записывай числа словами. 1943 → тысяча девятьсот сорок три. 15 → пятнадцать.
        """
    }

    // MARK: - Abbreviation Expansion

    private static func abbreviationExpansionSection() -> String {
        """
        АББРЕВИАТУРЫ: Раскрывай: т.д. → так далее, т.е. → то есть, г. → год/город, км → километров.
        Известные названия (NASA, ООН) оставляй как есть.
        """
    }

    // MARK: - Rephrasing

    private static func rephrasingSection() -> String {
        """
        АДАПТАЦИЯ: Перефразируй сложные конструкции для восприятия на слух. \
        Разбивай длинные обороты, убирай скобки и URL. Сохраняй смысл и стиль.
        """
    }

    // MARK: - Intensity

    private static func intensitySection(_ intensity: PreprocessingIntensity) -> String {
        switch intensity {
        case .minimal:
            return "ИНТЕНСИВНОСТЬ: Минимальная. Размечай только самые очевидные места."
        case .moderate:
            return "ИНТЕНСИВНОСТЬ: Умеренная. Баланс между естественностью и выразительностью."
        case .maximal:
            return "ИНТЕНСИВНОСТЬ: Максимальная. Отмечай все места для улучшения звучания."
        }
    }

    // MARK: - Examples

    private static func examples(for provider: TTSProvider, options: PreprocessingOptions) -> String {
        switch provider {
        case .qwenLocal where options.emotionMarkup:
            return """
            ПРИМЕРЫ (вход → выход):
            Вход: Через базарную площадь идёт полицейский надзиратель Очумелов.
            Выход: Через базарную площадь идёт полицейский надзиратель Очумелов.

            Вход: За ним шагает рыжий городовой с решетом.
            Выход: За ним шагает рыжий городовой с решетом.

            Вход: Так ты кусаться, окаянная? — слышит вдруг Очумелов.
            Выход: [angry] Так ты кусаться, окаянная? — слышит вдруг Очумелов.

            Вход: Братцы, не пущай! Нынче не велено кусаться!
            Выход: [shouting] Братцы, не пущай! Нынче не велено кусаться!

            Вход: Кругом тишина... На площади ни души.
            Выход: Кругом тишина... На площади ни души.

            Вход: Ура! Мы победили! Это потрясающе!
            Выход: [excited] Ура! Мы победили! Это потрясающе!

            Обрати внимание: большинство фраз идут БЕЗ тега.
            """

        case .kokoro where options.emotionMarkup:
            return """
            ПРИМЕРЫ (вход → выход):
            Вход: Ура! Мы победили!
            Выход: <emotion type="happy">Ура! Мы победили!</emotion>

            Вход: Через площадь идёт надзиратель.
            Выход: Через площадь идёт надзиратель.
            """

        default:
            return """
            ПРИМЕРЫ (вход → выход):
            Вход: Через базарную площадь идёт полицейский надзиратель Очумелов.
            Выход: Через базарную площадь идёт полицейский надзиратель Очумелов.

            Вход: Так ты кусаться, окаянная? — слышит вдруг Очумелов.
            Выход: Так ты кусаться, окаянная? — слышит вдруг Очумелов.
            """
        }
    }
}
