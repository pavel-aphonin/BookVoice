//
//  VoiceProfileCreateSheet.swift
//  BookVoice
//

import SwiftUI
import SwiftData

struct VoiceProfileCreateSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services
    @Bindable var viewModel: VoiceLibraryViewModel

    @State private var creationMode: CreationMode = .fromSample

    enum CreationMode {
        case fromSample
        case fromModel
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Новый голос")
                    .font(.title2.weight(.bold))
                Spacer()
                Button {
                    viewModel.resetForm()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()

            VStack(alignment: .leading, spacing: 20) {
                // Name
                glassPanel {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Название голоса")
                            .font(.callout.weight(.medium))
                        glassField {
                            TextField("Например: Диктор Анна", text: $viewModel.newName)
                                .textFieldStyle(.plain)
                                .font(.body)
                        }
                    }
                }

                // Description
                glassPanel {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Описание (необязательно)")
                            .font(.callout.weight(.medium))
                        glassField {
                            TextField("Краткое описание голоса", text: $viewModel.newDescription)
                                .textFieldStyle(.plain)
                                .font(.body)
                        }
                    }
                }

                // Creation mode picker
                Picker("Способ создания", selection: $creationMode) {
                    Text("Из записи голоса").tag(CreationMode.fromSample)
                    Text("У меня есть файл модели").tag(CreationMode.fromModel)
                }
                .pickerStyle(.segmented)

                switch creationMode {
                case .fromSample:
                    fromSampleSection
                case .fromModel:
                    fromModelSection
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Divider()

            // Footer
            HStack {
                Button("Отмена") {
                    viewModel.resetForm()
                    dismiss()
                }

                Spacer()

                switch creationMode {
                case .fromSample:
                    Button {
                        viewModel.startTraining(
                            in: modelContext,
                            rvcService: services.rvc,
                            notificationService: services.notification
                        )
                        dismiss()
                    } label: {
                        Label("Создать голос", systemImage: "waveform.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canCreateFromSample)

                case .fromModel:
                    Button {
                        viewModel.createProfile(in: modelContext)
                        dismiss()
                    } label: {
                        Label("Сохранить голос", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canCreate)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 560, height: 580)
        .presentationBackground(.ultraThinMaterial)
    }

    // MARK: - From Sample Section

    private var fromSampleSection: some View {
        VStack(spacing: 16) {
            glassPanel {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Запись или файл с образцом голоса")
                        .font(.callout.weight(.medium))

                    Text("Загрузите аудиозапись (от 30 секунд до 5 минут) с голосом, который хотите использовать. Приложение обучит модель по этому образцу. Обучение займёт 15\u{2013}20 минут.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        if let url = viewModel.newSampleAudioURL {
                            Label(url.lastPathComponent, systemImage: "waveform")
                                .font(.subheadline)
                                .lineLimit(1)
                        } else {
                            Text("Файл не выбран")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            viewModel.importSampleAudio()
                        } label: {
                            Label("Выбрать файл", systemImage: "waveform.badge.plus")
                        }
                    }
                    .padding(.top, 4)
                }
            }

            glassPanel {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Расшифровка (необязательно)")
                        .font(.callout.weight(.medium))

                    Text("Запишите текст того, что говорится на записи. Расшифровка используется для клонирования голоса при озвучке.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    glassField {
                        TextField("Текст того, что говорится на записи", text: $viewModel.newSampleTranscription, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.body)
                            .lineLimit(3...6)
                    }
                }
            }
        }
    }

    // MARK: - From Model Section

    private var fromModelSection: some View {
        glassPanel {
            VStack(alignment: .leading, spacing: 10) {
                Text("Файл обученной модели")
                    .font(.callout.weight(.medium))

                Text("Если вы уже обучали голос раньше и сохранили файл модели (.pth), выберите его здесь.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    if let url = viewModel.newModelURL {
                        Label(url.lastPathComponent, systemImage: "doc.fill")
                            .font(.subheadline)
                            .lineLimit(1)
                    } else {
                        Text("Файл не выбран")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        viewModel.importModel()
                    } label: {
                        Label("Выбрать файл", systemImage: "folder")
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Glass Helpers

    private func glassPanel<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(14)
            .background(.fill.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
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
}
