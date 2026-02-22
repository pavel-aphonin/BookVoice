//
//  View+GlassEffect.swift
//  BookVoice
//

import SwiftUI

struct GlassEffectModifier: ViewModifier {
    var cornerRadius: CGFloat
    var opacity: Double

    func body(content: Content) -> some View {
        content
            .background {
                VisualEffectBlur(
                    material: .hudWindow,
                    blendingMode: .behindWindow,
                    state: .active
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .opacity(opacity)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.glassStroke, lineWidth: AppConstants.glassStrokeWidth)
            }
    }
}

extension View {
    func glassEffect(
        cornerRadius: CGFloat = AppConstants.glassCornerRadius,
        opacity: Double = AppConstants.glassOpacity
    ) -> some View {
        modifier(GlassEffectModifier(cornerRadius: cornerRadius, opacity: opacity))
    }
}
