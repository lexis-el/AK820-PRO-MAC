import SwiftUI
import AK820Core

private let keyCaps: [String: String] = [
    "Grave": "`", "Minus": "-", "Equal": "=", "Backspace": "⌫", "Tab": "⇥", "LeftBracket": "[",
    "RightBracket": "]", "Backslash": "\\", "CapsLock": "⇪", "Semicolon": ";", "Quote": "'",
    "Enter": "⏎", "LeftShift": "⇧", "RightShift": "⇧", "Comma": ",", "Period": ".", "Slash": "/",
    "LeftCtrl": "Ctrl", "RightCtrl": "Ctrl", "LeftWin": "Win", "LeftAlt": "Alt", "RightAlt": "Alt",
    "Space": "", "Up": "↑", "Down": "↓", "Left": "←", "Right": "→", "Delete": "Del",
    "PageUp": "PgUp", "PageDown": "PgDn",
]

func keyCap(_ k: LayoutKey) -> String { keyCaps[k.name] ?? k.name }

/// The AK820 Pro drawn from the vendor's key rectangles. Click selects a key; ⌘/⇧-click adds to the selection.
struct KeyboardView: View {
    @Binding var selection: Set<Int>
    var fill: (LayoutKey) -> Color? = { _ in nil }
    var badge: (LayoutKey) -> String? = { _ in nil }
    var disabled: (LayoutKey) -> Bool = { _ in false }

    private let bounds: CGRect = keyGeometry.values.reduce(CGRect.null) { $0.union($1) }

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / (bounds.width + 16), geo.size.height / (bounds.height + 16))
            ZStack(alignment: .topLeading) {
                ForEach(layout, id: \.index) { k in
                    if let r = keyGeometry[k.index] {
                        keyView(k, size: CGSize(width: r.width * scale, height: r.height * scale))
                            .offset(x: (r.minX - bounds.minX + 8) * scale, y: (r.minY - bounds.minY + 8) * scale)
                    }
                }
            }
            .frame(width: (bounds.width + 16) * scale, height: (bounds.height + 16) * scale, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .windowBackgroundColor).opacity(0.6)))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio((bounds.width + 16) / (bounds.height + 16), contentMode: .fit)
    }

    @ViewBuilder
    private func keyView(_ k: LayoutKey, size: CGSize) -> some View {
        let selected = selection.contains(k.index)
        let off = disabled(k)
        let c = fill(k)
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(c ?? Color(nsColor: .controlBackgroundColor))
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(selected ? Color.accentColor : Color.secondary.opacity(0.4), lineWidth: selected ? 2.5 : 1)
            VStack(spacing: 0) {
                Text(keyCap(k)).font(.system(size: max(7, size.height * 0.3), weight: .medium))
                if let b = badge(k) {
                    Text(b).font(.system(size: max(6, size.height * 0.22))).foregroundColor(.accentColor).lineLimit(1)
                }
            }
            .foregroundColor(c.map { $0.isLight ? .black : .white } ?? .primary)
            .padding(1)
        }
        .frame(width: size.width, height: size.height)
        .opacity(off ? 0.35 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !off else { return }
            let mods = NSEvent.modifierFlags
            if mods.contains(.command) || mods.contains(.shift) {
                if selected { selection.remove(k.index) } else { selection.insert(k.index) }
            } else {
                selection = selected && selection.count == 1 ? [] : [k.index]
            }
        }
        .help(k.name)
    }
}

extension Color {
    var isLight: Bool {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .black
        return 0.299 * ns.redComponent + 0.587 * ns.greenComponent + 0.114 * ns.blueComponent > 0.6
    }
}
