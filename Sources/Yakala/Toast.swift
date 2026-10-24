import AppKit
import SwiftUI

/// Ekranın altında kısa süre görünen, tıklamaları engellemeyen ve odak çalmayan bildirim.
@MainActor
enum Toast {
    private static var panel: NSPanel?

    static func show(_ message: String, symbol: String = "checkmark.circle.fill") {
        panel?.close()

        let content = NSHostingView(rootView: ToastView(message: message, symbol: symbol))
        let size = content.fittingSize
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false
        panel.contentView = content
        if let frame = NSScreen.underMouse?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.minY + 72))
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        fade(panel, to: 1, duration: 0.15)
        Toast.panel = panel

        Task {
            try? await Task.sleep(for: .seconds(1.3))
            guard Toast.panel === panel else { return }
            fade(panel, to: 0, duration: 0.3)
            try? await Task.sleep(for: .seconds(0.3))
            guard Toast.panel === panel else { return }
            panel.close()
            Toast.panel = nil
        }
    }

    private static func fade(_ panel: NSPanel, to alpha: CGFloat, duration: TimeInterval) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            panel.animator().alphaValue = alpha
        }
    }
}

private struct ToastView: View {
    let message: String
    let symbol: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(.green)
            Text(message)
        }
        .font(.system(size: 13, weight: .medium))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .floatingBar()
        .padding(16) // gölge için pay
    }
}
