//
//  GlassTextField.swift
//  BookVoice
//

import SwiftUI

struct GlassTextField: View {
    let label: String
    @Binding var text: String
    var prompt: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !label.isEmpty {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .padding(10)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct GlassSecureField: View {
    let label: String
    @Binding var text: String
    var prompt: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !label.isEmpty {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            SecureField(prompt, text: $text)
                .textFieldStyle(.plain)
                .padding(10)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct GlassNumberField: View {
    let label: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 1...65535

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !label.isEmpty {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            TextField(
                label,
                value: $value,
                format: .number
            )
            .textFieldStyle(.plain)
            .padding(10)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
            .onChange(of: value) { _, newValue in
                value = min(max(newValue, range.lowerBound), range.upperBound)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        GlassTextField(label: "API URL", text: .constant("http://localhost"), prompt: "Введите URL")
        GlassNumberField(label: "Порт", value: .constant(8080))
        GlassSecureField(label: "API-ключ", text: .constant(""), prompt: "Введите API-ключ")
    }
    .frame(width: 300)
    .padding(40)
}
