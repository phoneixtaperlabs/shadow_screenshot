import Foundation
import CoreGraphics

struct ScreenshotResult {
    let id: String
    let timestamp: Date
    let filePath: String
    let fileSize: Int
    let width: Int
    let height: Int
    
    func toDict() -> [String: Any] {
        return [
            "id": id,
            "timestamp": timestamp.timeIntervalSince1970 * 1000,
            "filePath": filePath,
            "fileSize": fileSize,
            "width": width,
            "height": height
        ]
    }
}

@available(macOS 14.0, *)
actor CaptureService {
    // 1. Get the logger instance once for the entire class lifetime
    private var logger: ScreenshotLogger?
    
    private let screenshotService = ScreenCaptureKitService()
    private var captureTask: Task<Void, Never>?
    private var isCapturing = false
    private var convUUID: String = ""
    private var userUID: String = ""
    private var displayID: CGDirectDisplayID?
    private var imageOptions: ImageProcessor.ImageOptions?
    
    // 2. Reuse a single DateFormatter for performance
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
    
    init() async {
        // Now you can safely await for the shared logger
        self.logger = await ScreenshotLogger.shared
        // And safely call its isolated methods from within the actor
        self.logger?.info("CaptureService initialized.")
    }
    
    deinit {
        // 4. Log deinitialization using a capture list for safety
        Task { [logger] in
            logger?.info("CaptureService deinitialized.")
        }
        print("CaptureService is deintialized.")
    }
    
    func startCapturing(
        interval: TimeInterval,
        convUUID: String,
        userUID: String,
        displayID: CGDirectDisplayID?,
        imageOptions: ImageProcessor.ImageOptions? = nil,
        onCapture: @escaping (ScreenshotResult) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        logger?.info("Attempting to start capture with UUID: \(convUUID)")
        guard !isCapturing else {
            logger?.warning("Capture is already in progress.")
            return
        }
        
        isCapturing = true
        self.convUUID = convUUID
        self.userUID = userUID
        self.displayID = displayID
        self.imageOptions = imageOptions
        
        captureTask = Task {
            while !Task.isCancelled && isCapturing {
                do {
                    let result = try await captureScreenshot()
                    await MainActor.run {
                        onCapture(result)
                    }
                    // Log the successful capture event
                    self.logger?.info("Successfully captured screenshot for UUID: \(self.convUUID)")
                    
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                } catch {
                    await MainActor.run {
                        onError(error)
                    }
                    // Log the capture error
                    self.logger?.error("Failed to capture screenshot: \(error.localizedDescription)")
                    
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }
            }
        }
    }
    
    func stopCapturing() {
        logger?.info("Stopping capture for UUID: \(convUUID)")
        isCapturing = false
        convUUID = ""
        userUID = ""
        imageOptions = nil
        displayID = nil
        captureTask?.cancel()
        captureTask = nil
    }
    
    private func captureScreenshot() async throws -> ScreenshotResult {
        // Use the instance's shared formatter
        let timestampString = dateFormatter.string(from: Date())
        let fileName = "fullscreen_\(convUUID)_\(timestampString)"
        let finalImageOptions = imageOptions ?? .defaultJPEG
        
        do {
            let fileURL = try await screenshotService.saveScreenshot(
                fileName: fileName,
                uuid: convUUID,
                uid: userUID,
                displayID: displayID,
                imageOptions: finalImageOptions,
                excludeSelf: true
            )
            
            let fileData = try Data(contentsOf: fileURL)
            
            guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any],
                  let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight as String] as? Int else {
                
                let error = NSError(domain: "CaptureError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not read image properties"])
                logger?.error("Failed to read image properties for file: \(fileURL.path), error: \(error.localizedDescription)")
                throw error
            }
            
            return ScreenshotResult(
                id: convUUID,
                timestamp: Date(),
                filePath: fileURL.path,
                fileSize: fileData.count,
                width: width,
                height: height
            )
        } catch {
            logger?.error("Screenshot capture failed at an early stage: \(error.localizedDescription)")
            throw error
        }
    }
}
