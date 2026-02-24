//
//  ModelSettingsStepView.swift
//  BookVoice
//

import SwiftUI

struct ModelSettingsStepView: View {
    @Bindable var viewModel: ModelSettingsViewModel

    @State private var isShowingProviderGuide = false
    @State private var isShowingPromptGuide = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // TTS Provider picker
                providerSection

                // Provider-specific content
                switch viewModel.selectedProvider {
                case .silero, .kokoro, .qwenLocal:
                    localSetupSection
                case .elevenLabs:
                    elevenLabsSection
                case .qwenCloud:
                    dashScopeSection
                case .custom:
                    customAPISection
                }

                // System prompt
                systemPromptSection

                // Error message
                if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
            .padding(28)
        }
        .task(id: viewModel.selectedProvider) {
            viewModel.onProviderChanged()
            if viewModel.selectedProvider.isLocal {
                await viewModel.checkLocalPrerequisites()
            }
        }
        .sheet(isPresented: $isShowingProviderGuide) {
            ProviderGuideSheet()
        }
        .sheet(isPresented: $isShowingPromptGuide) {
            PromptGuideSheet()
        }
    }

    // MARK: - Glass Helpers

    private func glassPanel<Content: View>(
        cornerRadius: CGFloat = 10,
        padding: CGFloat = 14,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(padding)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
            )
    }

    private func glassField<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.fill.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Provider Picker

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Модель озвучки")
                    .font(.title3.weight(.semibold))

                Button {
                    isShowingProviderGuide = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Подробнее о моделях озвучки")
            }

            HStack(spacing: 12) {
                Picker("Провайдер", selection: $viewModel.selectedProvider) {
                    ForEach(TTSProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: 280)

                Text(providerBadge)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(providerBadgeColor.opacity(0.15))
                    .foregroundStyle(providerBadgeColor)
                    .clipShape(Capsule())
            }

            Text(providerDescription)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var providerBadge: String {
        switch viewModel.selectedProvider {
        case .silero, .kokoro, .qwenLocal: "Бесплатно"
        case .elevenLabs, .qwenCloud: "Платно"
        case .custom: "Для специалистов"
        }
    }

    private var providerBadgeColor: Color {
        switch viewModel.selectedProvider {
        case .silero, .kokoro, .qwenLocal: .green
        case .elevenLabs, .qwenCloud: .orange
        case .custom: .purple
        }
    }

    private var providerDescription: String {
        switch viewModel.selectedProvider {
        case .silero:
            "Бесплатная модель. Работает прямо на вашем компьютере, интернет не нужен. Хорошо читает на русском."
        case .kokoro:
            "Бесплатная модель с более естественным голосом. Лучше всего читает на английском. Интернет не нужен."
        case .elevenLabs:
            "Платный сервис с самыми реалистичными голосами. Нужен интернет и регистрация на сайте ElevenLabs."
        case .qwenLocal:
            "Бесплатная модель с поддержкой 10 языков и имитацией голоса. Работает на вашем компьютере."
        case .qwenCloud:
            "Платный сервис от Alibaba. Высокое качество без нагрузки на ваш компьютер. Нужен интернет."
        case .custom:
            "Для продвинутых пользователей. Подключение к собственному серверу озвучки."
        }
    }

    // MARK: - Local Setup Section (Silero / Kokoro)

    private var localSetupSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Настройка \(viewModel.selectedProvider.displayName)")
                .font(.title3.weight(.semibold))

            if viewModel.localSetupState != .notStarted {
                glassPanel(cornerRadius: 10, padding: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        componentRow(
                            title: "Python 3",
                            helpText: "Python \u{2014} язык программирования, на котором работают модели озвучки. Устанавливается один раз и не влияет на производительность вашего компьютера.",
                            status: viewModel.pythonStatus,
                            isLast: false
                        )
                        componentRow(
                            title: "Библиотеки для озвучки",
                            helpText: "Программные модули, которые позволяют модели преобразовывать текст в речь. Могут занимать 2\u{2013}5 ГБ на диске (включают нейросетевые модели).",
                            status: viewModel.dependenciesStatus,
                            isLast: false
                        )
                        componentRow(
                            title: "Сервер озвучки",
                            helpText: "Небольшая программа, которая запускается в фоне и обрабатывает запросы на озвучку. Работает только пока открыт BookVoice и автоматически завершается при закрытии.",
                            status: viewModel.serverStatus,
                            isLast: true
                        )
                    }
                    .padding(14)
                }
            }

            // Status message
            if let message = viewModel.setupMessage {
                HStack(alignment: .top, spacing: 8) {
                    if viewModel.isSettingUp
                        || viewModel.localSetupState == .checking
                    {
                        ProgressView()
                            .controlSize(.small)
                    } else if viewModel.localSetupState == .completed {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if viewModel.localSetupState == .failed
                        || viewModel.localSetupState == .needsPython
                    {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }

                    Text(message)
                        .font(.body)
                        .foregroundStyle(messageColor)
                }
            }

            localActionButtons

            if viewModel.localSetupState == .needsInstall
                || viewModel.localSetupState == .needsPython
            {
                Text(
                    "Первая настройка может занять несколько минут. Потребуется подключение к интернету."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var localActionButtons: some View {
        switch viewModel.localSetupState {
        case .needsPython:
            HStack(spacing: 12) {
                Link(
                    destination: URL(
                        string: "https://www.python.org/downloads/")!
                ) {
                    Label(
                        "Скачать Python", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Проверить снова") {
                    Task { await viewModel.checkLocalPrerequisites() }
                }
                .controlSize(.large)
            }

        case .needsInstall:
            Button {
                Task { await viewModel.beginLocalSetup() }
            } label: {
                Label(
                    "Установить компоненты",
                    systemImage: "arrow.down.circle")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        case .failed:
            Button {
                Task { await viewModel.beginLocalSetup() }
            } label: {
                Label("Попробовать снова", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        case .completed:
            Button {
                Task { await viewModel.reinstallDependencies() }
            } label: {
                Label("Переустановить компоненты", systemImage: "arrow.clockwise")
            }
            .controlSize(.regular)
            .help("Если озвучка не работает из-за ошибок, попробуйте переустановить компоненты")

        default:
            EmptyView()
        }
    }

    private var messageColor: Color {
        switch viewModel.localSetupState {
        case .completed: .green
        case .failed, .needsPython: .orange
        default: .secondary
        }
    }

    private func componentRow(
        title: String,
        helpText: String,
        status: ModelSettingsViewModel.ComponentStatus,
        isLast: Bool
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                statusIcon(for: status)
                    .frame(width: 20, height: 20)

                Text(title)
                    .font(.body)

                HelpTipButton(text: helpText)

                Spacer()

                Text(statusText(for: status))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)

            if !isLast {
                Divider()
                    .padding(.leading, 30)
            }
        }
    }

    @ViewBuilder
    private func statusIcon(
        for status: ModelSettingsViewModel.ComponentStatus
    ) -> some View {
        switch status {
        case .pending:
            Image(systemName: "circle")
                .foregroundStyle(.quaternary)
        case .checking, .installing:
            ProgressView()
                .controlSize(.mini)
        case .ready:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .notInstalled:
            Image(systemName: "circle.dashed")
                .foregroundStyle(.orange)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    private func statusText(
        for status: ModelSettingsViewModel.ComponentStatus
    ) -> String {
        switch status {
        case .pending: "Ожидает"
        case .checking: "Проверяю\u{2026}"
        case .ready: "Готово"
        case .notInstalled: "Не установлено"
        case .installing: "Устанавливается\u{2026}"
        case .failed(let msg): msg
        }
    }

    // MARK: - ElevenLabs Section

    private var elevenLabsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Подключение к ElevenLabs")
                .font(.title3.weight(.semibold))

            glassPanel {
                VStack(alignment: .leading, spacing: 10) {
                    Text("API-ключ")
                        .font(.callout.weight(.medium))

                    glassField {
                        SecureField(
                            "API-ключ",
                            text: $viewModel.apiKey,
                            prompt: Text(
                                "Вставьте ваш API-ключ ElevenLabs")
                        )
                        .textFieldStyle(.plain)
                        .font(.body)
                    }

                    Link(
                        "Получить ключ на elevenlabs.com \u{2192}",
                        destination: URL(string: "https://elevenlabs.io")!
                    )
                    .font(.callout)
                }
            }

            connectionTestRow
        }
    }

    // MARK: - DashScope Section (Qwen Cloud)

    private var dashScopeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Подключение к DashScope")
                .font(.title3.weight(.semibold))

            glassPanel {
                VStack(alignment: .leading, spacing: 10) {
                    Text("API-ключ DashScope")
                        .font(.callout.weight(.medium))

                    glassField {
                        SecureField(
                            "API-ключ",
                            text: $viewModel.dashScopeAPIKey,
                            prompt: Text(
                                "Вставьте ваш API-ключ DashScope")
                        )
                        .textFieldStyle(.plain)
                        .font(.body)
                    }

                    Link(
                        "Получить ключ на dashscope.console.aliyun.com \u{2192}",
                        destination: URL(string: "https://dashscope.console.aliyun.com/")!
                    )
                    .font(.callout)
                }
            }

            connectionTestRow
        }
    }

    // MARK: - Custom API Section

    private var customAPISection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Подключение к серверу")
                .font(.title3.weight(.semibold))

            glassPanel {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("URL сервера")
                                .font(.callout.weight(.medium))
                            glassField {
                                TextField(
                                    "URL",
                                    text: $viewModel.apiURL,
                                    prompt: Text("http://localhost")
                                )
                                .textFieldStyle(.plain)
                                .font(.body)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Порт")
                                .font(.callout.weight(.medium))
                            glassField {
                                TextField(
                                    "Порт",
                                    value: $viewModel.apiPort,
                                    format: .number
                                )
                                .textFieldStyle(.plain)
                                .font(.body)
                                .frame(width: 80)
                            }
                        }
                    }

                    Text(
                        "Сервер должен поддерживать API: POST /api/tts, GET /api/models"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }

            connectionTestRow
        }
    }

    // MARK: - Connection Test Row

    private var connectionTestRow: some View {
        HStack {
            Button {
                Task { await viewModel.testConnection() }
            } label: {
                Label(
                    viewModel.isTestingConnection
                        ? "Проверяю\u{2026}" : "Проверить подключение",
                    systemImage: "network"
                )
            }
            .controlSize(.large)
            .disabled(
                viewModel.isTestingConnection || !isConnectionTestEnabled)

            if let result = viewModel.connectionTestResult {
                Label(
                    result,
                    systemImage: viewModel.connectionTestSuccess
                        ? "checkmark.circle.fill"
                        : "xmark.circle.fill"
                )
                .font(.callout)
                .foregroundStyle(
                    viewModel.connectionTestSuccess ? .green : .red
                )
                .lineLimit(2)
            }
        }
    }

    private var isConnectionTestEnabled: Bool {
        switch viewModel.selectedProvider {
        case .elevenLabs:
            return !viewModel.apiKey.isEmpty
        case .qwenCloud:
            return !viewModel.dashScopeAPIKey.isEmpty
        case .custom:
            return !viewModel.apiURL.isEmpty && viewModel.apiPort > 0
        default:
            return false
        }
    }

    // MARK: - System Prompt

    private var systemPromptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Инструкции для озвучки")
                    .font(.title3.weight(.semibold))

                Button {
                    isShowingPromptGuide = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Подробнее об инструкциях")

                Spacer()

                if viewModel.systemPrompt.isEmpty {
                    Button {
                        viewModel.insertDefaultPrompt()
                    } label: {
                        Label(
                            "Вставить стандартную",
                            systemImage: "text.badge.plus")
                    }
                    .controlSize(.regular)
                }
            }

            glassPanel(cornerRadius: 10, padding: 4) {
                TextEditor(text: $viewModel.systemPrompt)
                    .font(.body)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                    .padding(6)
            }

            Text(
                "Необязательно. Подскажите модели, как именно нужно читать текст."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Help Tip Button (small popover)

private struct HelpTipButton: View {
    let text: String
    @State private var isShowingPopover = false

    var body: some View {
        Button {
            isShowingPopover.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingPopover, arrowEdge: .trailing) {
            Text(text)
                .font(.callout)
                .padding(12)
                .frame(maxWidth: 280)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Provider Guide Sheet

private struct ProviderGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Какую озвучку выбрать?")
                    .font(.title2.weight(.bold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Если вы не знаете, что выбрать \u{2014} начните с Silero для русских книг или Kokoro для английских. Это бесплатно и не требует интернета.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)

                    providerCard(
                        icon: "desktopcomputer",
                        name: "Silero",
                        badge: "Бесплатно",
                        badgeColor: .green,
                        qualities: [
                            "Работает прямо на вашем компьютере, интернет не нужен",
                            "Бесплатная, без ограничений и регистрации",
                            "Хорошо читает на русском языке",
                            "Голос звучит ровно, как робот-диктор",
                        ],
                        recommendation:
                            "Лучший выбор для русских книг. Просто установите и пользуйтесь."
                    )

                    providerCard(
                        icon: "waveform",
                        name: "Kokoro",
                        badge: "Бесплатно",
                        badgeColor: .green,
                        qualities: [
                            "Работает на вашем компьютере, интернет не нужен",
                            "Голос звучит более живо и естественно",
                            "Лучше всего читает на английском языке",
                            "Нужен более мощный компьютер",
                        ],
                        recommendation:
                            "Лучший выбор для английских книг с естественным звучанием."
                    )

                    providerCard(
                        icon: "cloud",
                        name: "ElevenLabs",
                        badge: "Платно",
                        badgeColor: .orange,
                        qualities: [
                            "Самый реалистичный голос \u{2014} как живой человек",
                            "Большой выбор голосов на разных языках",
                            "Нужен интернет и регистрация на сайте elevenlabs.io",
                            "Есть немного бесплатного времени, дальше \u{2014} подписка",
                        ],
                        recommendation:
                            "Если хотите максимальное качество и готовы платить."
                    )

                    providerCard(
                        icon: "waveform.circle",
                        name: "Qwen3 (на компьютере)",
                        badge: "Бесплатно",
                        badgeColor: .green,
                        qualities: [
                            "Поддерживает 10 языков сразу",
                            "Умеет имитировать чужой голос по образцу",
                            "Работает на вашем компьютере, интернет не нужен",
                            "Нужен мощный компьютер с большим объёмом памяти",
                        ],
                        recommendation:
                            "Если нужна имитация голоса или много разных языков."
                    )

                    providerCard(
                        icon: "cloud.fill",
                        name: "Qwen3 (через интернет)",
                        badge: "Платно",
                        badgeColor: .orange,
                        qualities: [
                            "Всё считается на серверах \u{2014} ваш компьютер не нагружается",
                            "Высокое качество звучания",
                            "Нужен интернет и регистрация на сайте Alibaba Cloud",
                        ],
                        recommendation:
                            "Если хотите качественную озвучку, но компьютер не очень мощный."
                    )

                    providerCard(
                        icon: "server.rack",
                        name: "Свой сервер",
                        badge: "Для специалистов",
                        badgeColor: .purple,
                        qualities: [
                            "Подключение к любому серверу озвучки",
                            "Полный контроль над всеми настройками",
                            "Нужны технические знания",
                        ],
                        recommendation:
                            "Только для опытных пользователей, у которых уже есть свой сервер."
                    )
                }
                .padding(20)
            }
        }
        .frame(width: 520, height: 620)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        }
    }

    private func providerCard(
        icon: String,
        name: String,
        badge: String,
        badgeColor: Color,
        qualities: [String],
        recommendation: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 24)

                Text(name)
                    .font(.headline)

                Text(badge)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(badgeColor.opacity(0.15))
                    .foregroundStyle(badgeColor)
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(qualities, id: \.self) { quality in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\u{2022}")
                            .foregroundStyle(.secondary)
                        Text(quality)
                            .font(.callout)
                    }
                }
            }
            .padding(.leading, 32)

            Text(recommendation)
                .font(.callout)
                .foregroundStyle(.secondary)
                .italic()
                .padding(.leading, 32)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
        )
    }
}

// MARK: - Prompt Guide Sheet

private struct PromptGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Что такое инструкции для озвучки?")
                    .font(.title2.weight(.bold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(
                        "Инструкции \u{2014} это подсказка для модели озвучки, которая говорит ей, КАК именно нужно читать ваш текст. Это как если бы вы давали указания живому диктору перед записью."
                    )
                    .font(.body)

                    Divider()

                    sectionTitle("Можно не писать ничего")
                    Text(
                        "Если вы оставите поле пустым, модель будет читать текст стандартным образом \u{2014} ровно и нейтрально. Для большинства книг этого достаточно."
                    )
                    .font(.callout)

                    Divider()

                    sectionTitle("Примеры инструкций")

                    exampleCard(
                        title: "Для художественной книги",
                        text:
                            "Читай выразительно, как профессиональный диктор. Прямую речь читай с интонацией персонажа. Делай паузы между абзацами."
                    )

                    exampleCard(
                        title: "Для учебника",
                        text:
                            "Читай чётко и размеренно, как лектор. Термины произноси отчётливо. Не торопись."
                    )

                    exampleCard(
                        title: "Для детской книги",
                        text:
                            "Читай весело и эмоционально, как мама читает сказку ребёнку. Разным персонажам давай разные голоса."
                    )

                    exampleCard(
                        title: "Для документации",
                        text:
                            "Читай нейтральным деловым тоном. Аббревиатуры произноси по буквам. Числа читай полностью."
                    )

                    Divider()

                    sectionTitle("Совет")
                    Text(
                        "Если вы не знаете, что написать \u{2014} нажмите кнопку \u{00AB}Вставить стандартную\u{00BB}. Стандартная инструкция хорошо подходит для большинства художественных книг."
                    )
                    .font(.callout)
                }
                .padding(20)
            }
        }
        .frame(width: 480, height: 560)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
    }

    private func exampleCard(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.callout.weight(.medium))
            Text("\u{00AB}\(text)\u{00BB}")
                .font(.callout)
                .foregroundStyle(.secondary)
                .italic()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
        )
    }
}

#Preview {
    ModelSettingsStepView(
        viewModel: ModelSettingsViewModel(
            project: VoiceoverProject(title: "Test"),
            ttsService: MockTTSService()
        )
    )
    .frame(width: 700, height: 500)
}
