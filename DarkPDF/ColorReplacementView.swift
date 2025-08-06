import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct ColorReplacementView: View {
    let colors: [Color]
    var onReplace: (Color, Color) -> Void
    @State private var selected: Color?
    @State private var newColor: Color = .red
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            List(colors, id: \.self) { color in
                HStack {
                    Circle()
                        .fill(color)
                        .frame(width: 24, height: 24)
                    Text(hexString(for: color))
                    Spacer()
                    if let selected, selected.cgColor == color.cgColor {
                        Image(systemName: "checkmark")
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { selected = color }
            }

            if selected != nil {
                ColorPicker("New Color", selection: $newColor)
                    .padding(.vertical)
                Button("Replace") {
                    if let original = selected {
                        onReplace(original, newColor)
                        dismiss()
                    }
                }
            }

            Button("Cancel") { dismiss() }
                .padding(.top)
        }
        .padding()
        .frame(minWidth: 320, minHeight: 400)
    }

    private func hexString(for color: Color) -> String {
#if os(macOS)
        let ns = NSColor(color).usingColorSpace(.deviceRGB)!
        return String(format: "#%02X%02X%02X", Int(ns.redComponent * 255), Int(ns.greenComponent * 255), Int(ns.blueComponent * 255))
#else
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
#endif
    }
}

#Preview {
    ColorReplacementView(colors: [.red, .blue]) { _, _ in }
}
