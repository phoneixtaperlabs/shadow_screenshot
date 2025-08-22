import Cocoa
import SwiftUI
import CoreGraphics

@MainActor
final class OverlayWindowController: NSWindowController, NSWindowDelegate {
    private var autoCloseTask: Task<Void, Never>?
    private var onCloseCallback: (() -> Void)?
     
    init(overlayWindow: NSWindow, onClose: @escaping () -> Void) {
        super.init(window: overlayWindow)
        self.onCloseCallback = onClose
        overlayWindow.delegate = self
        overlayWindow.isReleasedWhenClosed = false
    }
     
    deinit {
        print("OverlayWindowController deinit")
        autoCloseTask?.cancel()
    }
     
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
     
    func setupAutoClose(after seconds: TimeInterval) {
        autoCloseTask?.cancel()
        autoCloseTask = Task {
            do {
                try await Task.sleep(for: .seconds(seconds))
                print("Auto-close task finished")
                self.closeWindow()
            } catch {
                print("Auto-close task was cancelled.")
            }
        }
    }
     
    func closeWindow() {
        autoCloseTask?.cancel()
        autoCloseTask = nil
        window?.close()
    }
     
    func windowWillClose(_ notification: Notification) {
        print("Window will close - cleaning up in controller")
        autoCloseTask?.cancel()
        autoCloseTask = nil
        onCloseCallback?()
        onCloseCallback = nil
        self.window = nil
    }
}
