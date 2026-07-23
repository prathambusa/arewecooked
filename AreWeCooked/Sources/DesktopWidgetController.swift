import AppKit
import SwiftUI

class DesktopWidgetController: NSObject, NSWindowDelegate {
    static let shared = DesktopWidgetController()
    private var window: NSPanel?
    private var hostingView: NSHostingView<DesktopWidgetView>?
    private var timer: Timer?

    private let positionKey = "widget_position"

    func show() {
        if window == nil { createWindow() }
        window?.orderFront(nil)
        startRefreshTimer()
        refresh()
    }

    func refresh() {
        let provider = UserDefaults.standard.selectedProvider
        guard let key = KeychainManager.load(for: provider), !key.isEmpty else {
            DispatchQueue.main.async { self.setView(.noKey, loading: false, provider: provider) }
            return
        }
        DispatchQueue.main.async { self.setView(self.currentSummary(), loading: true, provider: provider) }
        Task {
            do {
                try await APIService.shared.fetchAndStore(provider: provider)
                let saved = UserDefaults.appGroup.loadUsageSummary() ?? .noKey
                await MainActor.run { self.setView(saved, loading: false, provider: provider) }
            } catch {
                await MainActor.run {
                    var s = UsageSummary.noKey
                    s.hasError = true
                    s.errorMessage = error.localizedDescription
                    self.setView(s, loading: false, provider: provider)
                }
            }
        }
    }

    private func currentSummary() -> UsageSummary {
        hostingView?.rootView.summary ?? .noKey
    }

    private func setView(_ summary: UsageSummary, loading: Bool, provider: Provider) {
        hostingView?.rootView = DesktopWidgetView(summary: summary, isLoading: loading, provider: provider)
    }

    private func createWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 255),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)))
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true

        let provider = UserDefaults.standard.selectedProvider
        let view = NSHostingView(rootView: DesktopWidgetView(summary: .noKey, isLoading: false, provider: provider))
        view.frame = NSRect(x: 0, y: 0, width: 320, height: 255)
        panel.contentView = view
        hostingView = view

        if let saved = UserDefaults.standard.string(forKey: positionKey) {
            panel.setFrameOrigin(NSPointFromString(saved))
        } else if let screen = NSScreen.main {
            let x = screen.visibleFrame.maxX - 340
            let y = screen.visibleFrame.maxY - 275
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        panel.delegate = self
        panel.orderFront(nil)
        self.window = panel
    }

    func windowDidMove(_ notification: Notification) {
        guard let origin = window?.frame.origin else { return }
        UserDefaults.standard.set(NSStringFromPoint(origin), forKey: positionKey)
    }

    func applyPreferences() {
        let newHeight = WidgetPreferences.current.widgetHeight
        if let panel = window, let hv = hostingView {
            let top = panel.frame.maxY
            let newY = top - newHeight
            panel.setFrame(NSRect(x: panel.frame.minX, y: newY, width: 320, height: newHeight), display: true, animate: true)
            hv.frame = NSRect(x: 0, y: 0, width: 320, height: newHeight)
        }
        refresh()
    }

    private func startRefreshTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }
}
