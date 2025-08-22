import Foundation
import ScreenCaptureKit
import CoreGraphics
import CoreMedia
import UniformTypeIdentifiers

@available(macOS 14.0, *)
struct ScreenCaptureKitService {
    enum CaptureError: Error {
        case noDisplayAvailable
        case screenshotFailed(Error)
        case invalidImage
        case fileSystemError(Error)
    }
    
    private let imageProcessor = ImageProcessor()
    
    func captureScreen(displayID: CGDirectDisplayID? = nil ,excludeSelf: Bool = true) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        
        let display = try selectDisplay(from: content, displayID: displayID)
        
        var applicationsToExclude: [SCRunningApplication] = []
        if excludeSelf {
            let currentProcessID = ProcessInfo.processInfo.processIdentifier
            if let selfApp = content.applications.first(where: { $0.processID == currentProcessID }) {
                applicationsToExclude.append(selfApp)
            }
        }
        
        let contentFilter = SCContentFilter(
            display: display,
            excludingApplications: applicationsToExclude,
            exceptingWindows: []
        )
        
        let configuration = SCStreamConfiguration()
        let targetSize: (width: Int, height: Int)
        targetSize = (width: display.width, height: display.height)
        
        configuration.width = targetSize.width
        configuration.height = targetSize.height
        configuration.backgroundColor = .black
        configuration.showsCursor = false
        configuration.capturesAudio = false
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        configuration.queueDepth = 3
        
        return try await captureAsImage(
            contentFilter: contentFilter,
            configuration: configuration
        )
    }
    
    func saveScreenshot(
        fileName: String? = nil,
        uuid: String? = nil,
        displayID: CGDirectDisplayID? = nil,
        imageOptions: ImageProcessor.ImageOptions = .defaultJPEG,
        excludeSelf: Bool = true
    ) async throws -> URL {
        let image = try await captureScreen(displayID: displayID,excludeSelf: excludeSelf)
        
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory,
                                                   in: .userDomainMask).first else {
            throw CaptureError.fileSystemError(CocoaError(.fileNoSuchFile))
        }
        
        var appDirectory = appSupportURL
            .appendingPathComponent("com.taperlabs.shadow")
        
        if let uuid = uuid, !uuid.isEmpty {
            appDirectory = appDirectory.appendingPathComponent(uuid)
        }
        
        appDirectory = appDirectory.appendingPathComponent("screenshots")
        
        do {
            try fileManager.createDirectory(at: appDirectory,
                                            withIntermediateDirectories: true,
                                            attributes: nil)
        } catch {
            throw CaptureError.fileSystemError(error)
        }
        
        let finalFileName: String
        if let fileName = fileName {
            if !fileName.contains(".") {
                finalFileName = "\(fileName).\(imageOptions.format.fileExtension)"
            } else {
                finalFileName = fileName
            }
        } else {
            finalFileName = imageProcessor.generateFileName(
                prefix: "screenshot",
                format: imageOptions.format,
                includeTimestamp: true
            )
        }
        
        let fileURL = appDirectory.appendingPathComponent(finalFileName)
        try imageProcessor.saveImage(image, to: fileURL, options: imageOptions)
        return fileURL
    }
    
    func saveScreenshot(
        to url: URL,
        imageOptions: ImageProcessor.ImageOptions = .defaultJPEG,
        excludeSelf: Bool = true
    ) async throws {
        let image = try await captureScreen(excludeSelf: excludeSelf)
        try imageProcessor.saveImage(image, to: url, options: imageOptions)
    }
    
    private func selectDisplay(from content: SCShareableContent, displayID: CGDirectDisplayID?) throws -> SCDisplay {
        if let displayID = displayID {
            guard let matchedDisplay = content.displays.first(where: { $0.displayID == displayID }) else {
                throw CaptureError.noDisplayAvailable
            }
            return matchedDisplay
        }
        
        guard let firstDisplay = content.displays.first else {
            throw CaptureError.noDisplayAvailable
        }
        return firstDisplay
    }
    
    private func captureAsImage(
        contentFilter: SCContentFilter,
        configuration: SCStreamConfiguration
    ) async throws -> CGImage {
        return try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(
                contentFilter: contentFilter,
                configuration: configuration
            ) { image, error in
                if let error = error {
                    continuation.resume(throwing: CaptureError.screenshotFailed(error))
                } else if let image = image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: CaptureError.invalidImage)
                }
            }
        }
    }
}
