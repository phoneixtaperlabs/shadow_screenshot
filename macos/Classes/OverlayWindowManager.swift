import Foundation
import CoreGraphics
import SwiftUI

@MainActor
final class OverlayWindowManager {
    static let shared = OverlayWindowManager()
    
    private var overlayWindowController: OverlayWindowController?
    private var targetWindowTimer: Timer?
    
    private init() {}
    
    deinit {
        print("OverlayWindowManager deinit")
    }
    
    struct WindowInfo {
        let windowID: CGWindowID
        let title: String
        let appName: String
        let bounds: CGRect
        let layer: Int
    }
    
    func showFullScreenOverlay(autoCloseAfter seconds: TimeInterval = 1.75) -> CGDirectDisplayID? {
        guard let screen = NSScreen.main else {
            print("Could not get main screen.")
            return nil
        }
        let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        createOverlay(
            frame: screen.frame,
            appName: "Full Screen",
            windowTitle: "Overlaying entire display",
            autoCloseAfter: seconds,
            targetWindowID: nil
        )
        return displayID
    }
    
    private func createOverlay(frame: NSRect, appName: String, windowTitle: String, autoCloseAfter seconds: TimeInterval, targetWindowID: CGWindowID?) {
        cleanupOverlay()
        
        print("Creating overlay for: \(appName) - \(windowTitle)")
        print("Frame: \(frame)")
        
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        configureOverlayWindow(window)
        
        let contentView = OverlayView(
            appName: appName,
            windowTitle: windowTitle,
            autoCloseIn: seconds,
            onClose: { [weak self] in
                self?.hideOverlay()
            }
        )
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = window.contentView?.bounds ?? frame
        hostingView.autoresizingMask = [.width, .height]
        
        window.contentView = hostingView
        
        overlayWindowController = OverlayWindowController(
            overlayWindow: window,
            onClose: { [weak self] in
                self?.handleWindowClosed()
            }
        )
        
        overlayWindowController?.setupAutoClose(after: seconds)
        
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        
        if let windowID = targetWindowID {
            startTrackingWindow(windowID)
        } else {
            stopTrackingWindow()
        }
    }
    
    func showOverlayOnApp(appName: String, autoCloseAfter seconds: TimeInterval = 3.0) {
        guard let windowInfo = findWindow(byAppName: appName) else {
            print("Could not find window for app: \(appName)")
            return
        }
        createOverlayForWindow(windowInfo, autoCloseAfter: seconds)
    }
    
    func showOverlayOnWindow(containing title: String, autoCloseAfter seconds: TimeInterval = 3.0) {
        guard let windowInfo = findWindow(byTitle: title) else {
            print("Could not find window with title containing: \(title)")
            return
        }
        createOverlayForWindow(windowInfo, autoCloseAfter: seconds)
    }
    
    func listAllWindows() -> [WindowInfo] {
        return getAllWindows()
    }
    
    private func getAllWindows() -> [WindowInfo] {
        var windowInfos: [WindowInfo] = []
        
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        
        for windowDict in windowList {
            guard let windowID = windowDict[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = windowDict[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = boundsDict["X"],
                  let y = boundsDict["Y"],
                  let width = boundsDict["Width"],
                  let height = boundsDict["Height"] else {
                continue
            }
            
            let appName = windowDict[kCGWindowOwnerName as String] as? String ?? ""
            let windowTitle = windowDict[kCGWindowName as String] as? String ?? ""
            let layer = windowDict[kCGWindowLayer as String] as? Int ?? 0
            
            if appName.isEmpty || layer != 0 {
                continue
            }
            
            let bounds = CGRect(x: x, y: y, width: width, height: height)
            
            windowInfos.append(WindowInfo(
                windowID: windowID,
                title: windowTitle,
                appName: appName,
                bounds: bounds,
                layer: layer
            ))
        }
        
        return windowInfos
    }
    
    private func findWindow(byAppName appName: String) -> WindowInfo? {
        let windows = getAllWindows()
        if let window = windows.first(where: { $0.appName == appName }) {
            return window
        }
        return windows.first(where: {
            $0.appName.lowercased().contains(appName.lowercased())
        })
    }
    
    private func findWindow(byTitle title: String) -> WindowInfo? {
        let windows = getAllWindows()
        return windows.first(where: {
            $0.title.lowercased().contains(title.lowercased())
        })
    }
    
    private func createOverlayForWindow(_ windowInfo: WindowInfo, autoCloseAfter seconds: TimeInterval = 3.0) {
        cleanupOverlay()
        
        print("Creating overlay for: \(windowInfo.appName) - \(windowInfo.title)")
        print("Auto-close after: \(seconds) seconds")
        print("Window bounds: \(windowInfo.bounds)")
        
        guard let screen = NSScreen.main else { return }
        let screenHeight = screen.frame.height
        
        let nsRect = NSRect(
            x: windowInfo.bounds.origin.x,
            y: screenHeight - windowInfo.bounds.origin.y - windowInfo.bounds.height,
            width: windowInfo.bounds.width,
            height: windowInfo.bounds.height
        )
        
        let window = NSWindow(
            contentRect: nsRect,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        configureOverlayWindow(window)
        
        let contentView = OverlayView(
            appName: windowInfo.appName,
            windowTitle: windowInfo.title,
            autoCloseIn: seconds,
            onClose: { [weak self] in
                self?.hideOverlay()
            }
        )
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = window.contentView?.bounds ?? nsRect
        hostingView.autoresizingMask = [.width, .height]
        
        window.contentView = hostingView
        
        overlayWindowController = OverlayWindowController(
            overlayWindow: window,
            onClose: { [weak self] in
                self?.handleWindowClosed()
            }
        )
        
        overlayWindowController?.setupAutoClose(after: seconds)
        
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        
        startTrackingWindow(windowInfo.windowID)
    }
    
    private func configureOverlayWindow(_ window: NSWindow) {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.sharingType = .none
//        window.styleMask.insert(.nonactivatingPanel)
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
    }
    
    private func startTrackingWindow(_ windowID: CGWindowID) {
        stopTrackingWindow()
        
        targetWindowTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateOverlayPosition(for: windowID)
        }
    }
    
    private func stopTrackingWindow() {
        targetWindowTimer?.invalidate()
        targetWindowTimer = nil
    }
    
    private func updateOverlayPosition(for windowID: CGWindowID) {
        guard let window = overlayWindowController?.window else { return }
        
        let options: CGWindowListOption = [.optionIncludingWindow]
        guard let windowList = CGWindowListCopyWindowInfo(options, windowID) as? [[String: Any]],
              let windowDict = windowList.first,
              let boundsDict = windowDict[kCGWindowBounds as String] as? [String: CGFloat],
              let x = boundsDict["X"],
              let y = boundsDict["Y"],
              let width = boundsDict["Width"],
              let height = boundsDict["Height"] else {
            cleanupOverlay()
            return
        }
        
        guard let screen = NSScreen.main else { return }
        let screenHeight = screen.frame.height
        
        let nsRect = NSRect(
            x: x,
            y: screenHeight - y - height,
            width: width,
            height: height
        )
        
        window.setFrame(nsRect, display: true, animate: false)
    }
    
    func hideOverlay() {
        cleanupOverlay()
    }
    
    private func handleWindowClosed() {
        print("Window closed callback received")
        stopTrackingWindow()
        overlayWindowController = nil
    }
    
    private func cleanupOverlay() {
        print("Cleaning up overlay...")
        stopTrackingWindow()
        if let controller = overlayWindowController {
            controller.closeWindow()
        }
        overlayWindowController = nil
        print("Overlay cleanup complete")
    }
}
