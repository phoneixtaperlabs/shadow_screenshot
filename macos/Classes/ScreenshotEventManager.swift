import Foundation
import FlutterMacOS

@MainActor
final class ScreenshotEventManager: NSObject, FlutterStreamHandler {
    nonisolated static let shared = ScreenshotEventManager()
    
    private var eventSink: FlutterEventSink?
    private var captureService: CaptureService?
    private var logger: ScreenshotLogger?
    
    nonisolated private override init() {
        super.init()
        
        Task { @MainActor in
            self.logger = await ScreenshotLogger.shared
            self.logger?.info("ScreenshotEventManager initialized.")
        }
    }
    
    nonisolated func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        Task { @MainActor in
            self.logger?.info("Received onListen call from Flutter.")
            let params = arguments as? [String: Any]
            let uuid = params?["convUUID"] as? String
            let interval = params?["interval"] as? Double ?? 3.0
            let imageOptions = self.parseImageOptions(from: params?["imageOptions"] as? [String: Any])
            self.eventSink = events
            let displayID = OverlayWindowManager.shared.showFullScreenOverlay()
            await self.startCapturing(interval: interval, convUUID: uuid, displayID: displayID, imageOptions: imageOptions)
        }
        return nil
    }
    
    nonisolated func onCancel(withArguments arguments: Any?) -> FlutterError? {
        Task { @MainActor in
            self.logger?.info("Received onCancel call from Flutter.")
            await self.stopCapturing()
            self.eventSink = nil
        }
        return nil
    }
    
    private func startCapturing(interval: TimeInterval, convUUID: String?, displayID: CGDirectDisplayID? = nil, imageOptions: ImageProcessor.ImageOptions? = nil) async {
        guard #available(macOS 14.0, *) else {
            self.logger?.error("Screenshot requires macOS 14.0 or later.")
            sendError("Screenshot requires macOS 14.0 or later")
            return
        }
        
        guard let uuid = convUUID, !uuid.isEmpty else {
            self.logger?.error("Missing or invalid convUUID")
            sendError("Missing or invalid convUUID")
            return
        }
        
        captureService = await CaptureService()
        
        await captureService?.startCapturing(
            interval: interval,
            convUUID: uuid,
            displayID: displayID,
            imageOptions: imageOptions,
            onCapture: { [weak self] result in
                self?.sendScreenshot(result)
            },
            onError: { [weak self] error in
                self?.sendError(error.localizedDescription)
            }
        )
    }
    
    private func stopCapturing() async {
        guard captureService != nil else {
            self.logger?.warning("Attempted to stop capturing, but captureService is not active.")
            return
        }
        
        self.logger?.info("Stopping capture.")
        await captureService?.stopCapturing()
        captureService = nil
    }
    
    private func sendScreenshot(_ screenshot: ScreenshotResult) {
        var data = screenshot.toDict()
        data["type"] = "screenshot"
        eventSink?(data)
    }
    
    private func sendError(_ message: String) {
        eventSink?(FlutterError(
            code: "SCREENSHOT_ERROR",
            message: message,
            details: nil
        ))
    }
    
    private func parseImageOptions(from dictionary: [String: Any]?) -> ImageProcessor.ImageOptions? {
        guard let dict = dictionary else {
            return nil
        }
        
        let formatStr = dict["format"] as? String ?? "jpeg"
        let format = ImageProcessor.ImageFormat(rawValue: formatStr) ?? .jpeg
        let quality = dict["quality"] as? Double ?? 0.9
        
        var resizeMode: ImageProcessor.ResizeMode? = nil
        if let resizeDict = dict["resize"] as? [String: Any],
           let modeStr = resizeDict["mode"] as? String {
            
            switch modeStr {
            case "exact":
                if let width = resizeDict["width"] as? Int, let height = resizeDict["height"] as? Int {
                    resizeMode = .exact(width: width, height: height)
                }
            case "fit":
                if let maxWidth = resizeDict["maxWidth"] as? Int, let maxHeight = resizeDict["maxHeight"] as? Int {
                    resizeMode = .fit(maxWidth: maxWidth, maxHeight: maxHeight)
                }
            case "fill":
                if let width = resizeDict["width"] as? Int, let height = resizeDict["height"] as? Int {
                    resizeMode = .fill(width: width, height: height)
                }
            case "scale":
                if let factor = resizeDict["factor"] as? Double {
                    resizeMode = .scale(factor: factor)
                }
            case "width":
                if let width = resizeDict["width"] as? Int {
                    resizeMode = .width(width)
                }
            case "height":
                if let height = resizeDict["height"] as? Int {
                    resizeMode = .height(height)
                }
            default:
                self.logger?.warning("Unknown resize mode: \(modeStr)")
                print("Unknown resize mode: \(modeStr)")
            }
        }
        
        return ImageProcessor.ImageOptions(format: format, quality: quality, resize: resizeMode)
    }
}
