import Cocoa
import SwiftUI
import CoreGraphics

@MainActor
final class OverlayWindowController: NSWindowController, NSWindowDelegate {
    
    // 1. private optional property to hold the logger instance
    private var logger: ScreenshotLogger?
    
    private var autoCloseTask: Task<Void, Never>?
    private var onCloseCallback: (() -> Void)?
    
    init(overlayWindow: NSWindow, onClose: @escaping () -> Void) {
        super.init(window: overlayWindow)
        self.onCloseCallback = onClose
        overlayWindow.delegate = self
        overlayWindow.isReleasedWhenClosed = false
        
        // 2. Initialize the logger in the init method using a Task
        Task {
            self.logger = await ScreenshotLogger.shared
            self.logger?.info("OverlayWindowController initialized")
        }
    }
    
    deinit {
        // ⚠️ This log is not guaranteed to execute due to deinit's nature
        // 올바른 해결 방법: 캡처 리스트 사용
        Task { [logger = self.logger] in
            // 이제 클로저는 self.logger가 아닌 캡처된 'logger' 변수를 사용합니다.
            // deinit이 끝나도 logger 인스턴스는 유효하므로 안전합니다.
            logger?.info("OverlayWindowController deinitialized")
        }
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
                // 3. Reuse the logger instance
                self.logger?.info("Auto-close task finished.")
                self.closeWindow()
            } catch {
                self.logger?.info("Auto-close task was cancelled.")
            }
        }
    }
    
    func closeWindow() {
        autoCloseTask?.cancel()
        autoCloseTask = nil
        window?.close()
    }
    
    func windowWillClose(_ notification: Notification) {
        // 3. Reuse the logger instance
        logger?.info("Window will close - cleaning up in controller.")
        
        autoCloseTask?.cancel()
        autoCloseTask = nil
        onCloseCallback?()
        onCloseCallback = nil
        self.window = nil
    }
}
//final class OverlayWindowController: NSWindowController, NSWindowDelegate {
//    private var autoCloseTask: Task<Void, Never>?
//    private var onCloseCallback: (() -> Void)?
//     
//    init(overlayWindow: NSWindow, onClose: @escaping () -> Void) {
//        super.init(window: overlayWindow)
//        self.onCloseCallback = onClose
//        overlayWindow.delegate = self
//        overlayWindow.isReleasedWhenClosed = false
//    }
//     
//    deinit {
//        print("OverlayWindowController deinit")
//        autoCloseTask?.cancel()
//    }
//     
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) not implemented")
//    }
//     
//    func setupAutoClose(after seconds: TimeInterval) {
//        autoCloseTask?.cancel()
//        autoCloseTask = Task {
//            do {
//                try await Task.sleep(for: .seconds(seconds))
//                print("Auto-close task finished")
//                self.closeWindow()
//            } catch {
//                print("Auto-close task was cancelled.")
//            }
//        }
//    }
//     
//    func closeWindow() {
//        autoCloseTask?.cancel()
//        autoCloseTask = nil
//        window?.close()
//    }
//     
//    func windowWillClose(_ notification: Notification) {
//        print("Window will close - cleaning up in controller")
//        autoCloseTask?.cancel()
//        autoCloseTask = nil
//        onCloseCallback?()
//        onCloseCallback = nil
//        self.window = nil
//    }
//}
