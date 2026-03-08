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
            ЗАПРЕЩЕНО добавлять [теги], <теги>, {теги} или любую другую разметку.
            Всё, что не является обычным текстом и пунктуацией, будет произнесено буквально.
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
            ЭМОЦИИ: Передавай эмоции ТОЛЬКО через пунктуацию:
            ! — энергичность и радость, ... — задумчивость, ? — удивление, — — пауза.
            КАТЕГОРИЧЕСКИ ЗАПРЕЩЕНО добавлять теги в квадратных скобках: [happy], [sad], [whisper] и подобные.
            КАТЕГОРИЧЕСКИ ЗАПРЕЩЕНО добавлять теги в угловых скобках: <emotion>, <prosody> и подобные.
            Любые теги будут озвучены как обычный текст и испортят аудиокнигу.
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
        УДАРЕНИЯ: Проставь знак ударения (U+0301, комбинирующий акут) после ударной гласной \
        В КАЖДОМ многосложном слове. Это критически важно для правильного произношения.

        Правила:
        1. КАЖДОЕ слово с двумя и более слогами получает ударение, без исключений: замо́к, де́рево, челове́к, полице́йский.
        2. Знак ставится СРАЗУ ПОСЛЕ ударной гласной: а́, е́, и́, о́, у́, ы́, э́, ю́, я́.
        3. Архаичные, устаревшие и церковнославянские слова — используй историческое произношение: \
        ужо́, намедни́, токмо́, благоле́пие, сотвори́ша, нонче (односложн.).
        4. Просторечия и диалектизмы — как они реально произносятся: пущай — пуща́й, ихний — и́хний.
        5. Букву «ё» НЕ размечай — она всегда ударная (её, ещё, всё).
        6. Односложные слова (дом, сад, мне, тут, вдруг) — НЕ размечай.
        7. Предлоги, союзы, частицы (в, на, и, но, же, ли, бы, из, к, у, с) — НЕ размечай.
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
        let s = options.stressMarks  // whether to show stressed examples

        switch provider {
        case .qwenLocal where options.emotionMarkup:
            let out1 = s ? "Че́рез база́рную пло́щадь идёт полице́йский надзира́тель Очуме́лов." : "Через базарную площадь идёт полицейский надзиратель Очумелов."
            let out2 = s ? "За ним шага́ет ры́жий городово́й с решето́м." : "За ним шагает рыжий городовой с решетом."
            let out3 = s ? "[angry] Так ты куса́ться, окая́нная? — слы́шит вдруг Очуме́лов." : "[angry] Так ты кусаться, окаянная? — слышит вдруг Очумелов."
            let out4 = s ? "[shouting] Бра́тцы, не пуща́й! Ны́нче не веле́но куса́ться!" : "[shouting] Братцы, не пущай! Нынче не велено кусаться!"
            let out5 = s ? "Круго́м тишина́... На пло́щади ни души́." : "Кругом тишина... На площади ни души."
            let stressNote = s ? " Ударение стоит в КАЖДОМ многосложном слове." : ""

            return """
            ПРИМЕРЫ (вход → выход):
            Вход: Через базарную площадь идёт полицейский надзиратель Очумелов.
            Выход: \(out1)

            Вход: За ним шагает рыжий городовой с решетом.
            Выход: \(out2)

            Вход: Так ты кусаться, окаянная? — слышит вдруг Очумелов.
            Выход: \(out3)

            Вход: Братцы, не пущай! Нынче не велено кусаться!
            Выход: \(out4)

            Вход: Кругом тишина... На площади ни души.
            Выход: \(out5)

            Обрати внимание: большинство фраз идут БЕЗ эмоционального тега.\(stressNote)
            """

        case .kokoro where options.emotionMarkup:
            let out1 = s ? "<emotion type=\"happy\">Ура́! Мы победи́ли!</emotion>" : "<emotion type=\"happy\">Ура! Мы победили!</emotion>"
            let out2 = s ? "Че́рез пло́щадь идёт надзира́тель." : "Через площадь идёт надзиратель."

            return """
            ПРИМЕРЫ (вход → выход):
            Вход: Ура! Мы победили!
            Выход: \(out1)

            Вход: Через площадь идёт надзиратель.
            Выход: \(out2)
            """

        default:
            let out1 = s ? "Че́рез база́рную пло́щадь идёт полице́йский надзира́тель Очуме́лов." : "Через базарную площадь идёт полицейский надзиратель Очумелов."
            let out2 = s ? "Так ты куса́ться, окая́нная? — слы́шит вдруг Очуме́лов." : "Так ты кусаться, окаянная? — слышит вдруг Очумелов."
            let stressNote = s ? "\n\nОбрати внимание: ударение стоит в КАЖДОМ многосложном слове." : ""

            return """
            ПРИМЕРЫ (вход → выход):
            Вход: Через базарную площадь идёт полицейский надзиратель Очумелов.
            Выход: \(out1)

            Вход: Так ты кусаться, окаянная? — слышит вдруг Очумелов.
            Выход: \(out2)\(stressNote)
            """
        }
    }
}
