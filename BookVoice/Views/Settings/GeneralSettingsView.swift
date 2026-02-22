//
//  GeneralSettingsView.swift
//  BookVoice
//

import SwiftUI

struct GeneralSettingsView: View {
    @Environment(ServiceContainer.self) private var services
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        Form {
            Section("По умолчанию") {
                if let vm = viewModel {
                    Picker("TTS-провайдер по умолчанию", selection: Bindable(vm).defaultProvider) {
                        ForEach(TTSProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }

                    Picker("Сегментация по умолчанию", selection: Bindable(vm).defaultSegmentation) {
                        ForEach(SegmentationStrategy.allCases, id: \.self) { strategy in
                            Text(strategy.displayName).tag(strategy)
                        }
                    }
                }
            }

            Section("Журнал") {
                Button("Открыть папку логов") {
                    viewModel?.openLogsFolder()
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if viewModel == nil {
                viewModel = SettingsViewModel(modelManager: services.modelManager)
            }
        }
    }
}

#Preview {
    GeneralSettingsView()
        .environment(ServiceContainer.mock)
        .frame(width: 400, height: 300)
}
