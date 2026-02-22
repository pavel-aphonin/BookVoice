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
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.glassStroke, lineWidth: AppConstants.glassStrokeWidth)
                }
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
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.glassStroke, lineWidth: AppConstants.glassStrokeWidth)
                }
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
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.glassStroke, lineWidth: AppConstants.glassStrokeWidth)
            }
            .onChange(of: value) { _, newValue in
                value = min(max(newValue, range.lowerBound), range.upperBound)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        GlassTextField(label: "API URL", text: .constant("http://localhost"), prompt: "Enter URL")
        GlassNumberField(label: "Port", value: .constant(8080))
        GlassSecureField(label: "API Key", text: .constant(""), prompt: "Enter API key")
    }
    .frame(width: 300)
    .padding(40)
    .background(
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
