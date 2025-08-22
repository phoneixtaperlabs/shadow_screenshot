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
    private let screenshotService = ScreenCaptureKitService()
    private var captureTask: Task<Void, Never>?
    private var isCapturing = false
    private var convUUID: String = ""
    private var displayID: CGDirectDisplayID?
    private var imageOptions: ImageProcessor.ImageOptions?
    
    deinit {
        print("CaptureService is deintialized.")
    }
    
    func startCapturing(
        interval: TimeInterval,
        convUUID: String,
        displayID: CGDirectDisplayID?,
        imageOptions: ImageProcessor.ImageOptions? = nil,
        onCapture: @escaping (ScreenshotResult) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        guard !isCapturing else { return }
        isCapturing = true
        self.convUUID = convUUID
        self.displayID = displayID
        self.imageOptions = imageOptions
        
        captureTask = Task {
            while !Task.isCancelled && isCapturing {
                do {
                    let result = try await captureScreenshot()
                    await MainActor.run {
                        onCapture(result)
                    }
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                } catch {
                    await MainActor.run {
                        onError(error)
                    }
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }
            }
        }
    }
    
    func stopCapturing() {
        isCapturing = false
        convUUID = ""
        imageOptions = nil
        displayID = nil
        captureTask?.cancel()
        captureTask = nil
    }
    
    private func captureScreenshot() async throws -> ScreenshotResult {
        let timestamp = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestampString = formatter.string(from: timestamp)
        let fileName = "fullscreen_\(convUUID)_\(timestampString)"
        let finalImageOptions = imageOptions ?? .defaultJPEG
        
        let fileURL = try await screenshotService.saveScreenshot(
            fileName: fileName,
            uuid: convUUID,
            displayID: displayID,
            imageOptions: finalImageOptions,
            excludeSelf: true
        )
        
        let fileData = try Data(contentsOf: fileURL)
        
        guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any],
              let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
              let height = properties[kCGImagePropertyPixelHeight as String] as? Int else {
            throw NSError(domain: "CaptureError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not read image properties"])
        }
        
        return ScreenshotResult(
            id: convUUID,
            timestamp: Date(),
            filePath: fileURL.path,
            fileSize: fileData.count,
            width: width,
            height: height
        )
    }
}
