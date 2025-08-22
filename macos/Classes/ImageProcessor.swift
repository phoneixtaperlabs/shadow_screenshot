import Foundation
import CoreGraphics
import UniformTypeIdentifiers
import ImageIO

struct ImageProcessor {
    enum ImageFormat: String, CaseIterable {
        case png = "png"
        case jpeg = "jpeg"
        case jpg = "jpg"
        case heic = "heic"
        
        var utType: UTType {
            switch self {
            case .png:
                return .png
            case .jpeg, .jpg:
                return .jpeg
            case .heic:
                return .heic
            }
        }
        
        var fileExtension: String {
            switch self {
            case .png:
                return "png"
            case .jpeg, .jpg:
                return "jpg"
            case .heic:
                return "heic"
            }
        }
        
        var supportsQuality: Bool {
            switch self {
            case .jpeg, .jpg, .heic:
                return true
            case .png:
                return false
            }
        }
        
        var isSupported: Bool {
            switch self {
            case .png, .jpeg, .jpg:
                return true
            case .heic:
                if #available(macOS 10.13, *) {
                    return true
                }
                return false
            }
        }
    }
    
    enum ResizeMode {
        case exact(width: Int, height: Int)
        case fit(maxWidth: Int, maxHeight: Int)
        case fill(width: Int, height: Int)
        case scale(factor: Double)
        case width(Int)
        case height(Int)
    }
    
    struct ImageOptions {
        let format: ImageFormat
        let quality: Double
        let resize: ResizeMode?
        
        init(format: ImageFormat = .png, quality: Double = 0.9, resize: ResizeMode? = nil) {
            self.format = format
            self.quality = min(max(quality, 0.0), 1.0)
            self.resize = resize
        }
        
        static let defaultPNG = ImageOptions(format: .png)
        static let defaultJPEG = ImageOptions(format: .jpeg, quality: 0.9)
        static let highQualityJPEG = ImageOptions(format: .jpeg, quality: 1.0)
        static let compressedJPEG = ImageOptions(format: .jpeg, quality: 0.7)
        static let thumbnailJPEG = ImageOptions(format: .jpeg, quality: 0.85, resize: .fit(maxWidth: 200, maxHeight: 200))
        static let webJPEG = ImageOptions(format: .jpeg, quality: 0.85, resize: .fit(maxWidth: 1200, maxHeight: 1200))
        static let hdJPEG = ImageOptions(format: .jpeg, quality: 0.9, resize: .exact(width: 1920, height: 1080))
        static let halfSize = ImageOptions(format: .jpeg, quality: 0.9, resize: .scale(factor: 0.5))
    }
    
    enum ProcessingError: Error, LocalizedError {
        case invalidDestination
        case conversionFailed
        case unsupportedFormat(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidDestination:
                return "Failed to create image destination"
            case .conversionFailed:
                return "Failed to convert image"
            case .unsupportedFormat(let format):
                return "Format '\(format)' is not supported for writing. Supported formats: PNG, JPEG, HEIC"
            }
        }
    }
    
    func resizeImage(_ image: CGImage, mode: ResizeMode) -> CGImage? {
        let originalWidth = Double(image.width)
        let originalHeight = Double(image.height)
        let aspectRatio = originalWidth / originalHeight
        
        var newWidth: Double
        var newHeight: Double
        
        switch mode {
        case .exact(let width, let height):
            newWidth = Double(width)
            newHeight = Double(height)
        case .fit(let maxWidth, let maxHeight):
            let maxAspectRatio = Double(maxWidth) / Double(maxHeight)
            if aspectRatio > maxAspectRatio {
                newWidth = Double(maxWidth)
                newHeight = newWidth / aspectRatio
            } else {
                newHeight = Double(maxHeight)
                newWidth = newHeight * aspectRatio
            }
        case .fill(let width, let height):
            let targetAspectRatio = Double(width) / Double(height)
            if aspectRatio > targetAspectRatio {
                newHeight = Double(height)
                newWidth = newHeight * aspectRatio
            } else {
                newWidth = Double(width)
                newHeight = newWidth / aspectRatio
            }
        case .scale(let factor):
            newWidth = originalWidth * factor
            newHeight = originalHeight * factor
        case .width(let width):
            newWidth = Double(width)
            newHeight = newWidth / aspectRatio
        case .height(let height):
            newHeight = Double(height)
            newWidth = newHeight * aspectRatio
        }
        
        let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        let bitmapInfo = image.bitmapInfo
        
        guard let context = CGContext(
            data: nil,
            width: Int(newWidth),
            height: Int(newHeight),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }
        
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        
        return context.makeImage()
    }
    
    func saveImage(
        _ image: CGImage,
        to url: URL,
        options: ImageOptions = .defaultPNG
    ) throws {
        guard options.format.isSupported else {
            throw ProcessingError.unsupportedFormat(options.format.rawValue)
        }
        
        let finalImage: CGImage
        if let resizeMode = options.resize,
           let resizedImage = resizeImage(image, mode: resizeMode) {
            finalImage = resizedImage
        } else {
            finalImage = image
        }
        
        var finalURL = url
        let pathExtension = url.pathExtension.lowercased()
        let expectedExtension = options.format.fileExtension
        
        if pathExtension != expectedExtension {
            finalURL = url.deletingPathExtension().appendingPathExtension(expectedExtension)
        }
        
        guard let destination = CGImageDestinationCreateWithURL(
            finalURL as CFURL,
            options.format.utType.identifier as CFString,
            1,
            nil
        ) else {
            throw ProcessingError.invalidDestination
        }
        
        let properties = createImageProperties(for: options)
        CGImageDestinationAddImage(destination, finalImage, properties as CFDictionary?)
        
        if !CGImageDestinationFinalize(destination) {
            throw ProcessingError.conversionFailed
        }
    }
    
    func imageToData(
        _ image: CGImage,
        options: ImageOptions = .defaultPNG
    ) throws -> Data {
        guard options.format.isSupported else {
            throw ProcessingError.unsupportedFormat(options.format.rawValue)
        }
        
        let finalImage: CGImage
        if let resizeMode = options.resize,
           let resizedImage = resizeImage(image, mode: resizeMode) {
            finalImage = resizedImage
        } else {
            finalImage = image
        }
        
        let data = NSMutableData()
        
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            options.format.utType.identifier as CFString,
            1,
            nil
        ) else {
            throw ProcessingError.invalidDestination
        }
        
        let properties = createImageProperties(for: options)
        CGImageDestinationAddImage(destination, finalImage, properties as CFDictionary?)
        
        if !CGImageDestinationFinalize(destination) {
            throw ProcessingError.conversionFailed
        }
        
        return data as Data
    }
    
    func estimateFileSize(
        _ image: CGImage,
        options: ImageOptions = .defaultPNG
    ) throws -> Int {
        let data = try imageToData(image, options: options)
        return data.count
    }
    
    func generateFileName(
        prefix: String = "screenshot",
        format: ImageFormat = .png,
        includeTimestamp: Bool = true
    ) -> String {
        var fileName = prefix
        
        if includeTimestamp {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let timestamp = formatter.string(from: Date())
            fileName = "\(prefix)_\(timestamp)"
        }
        
        return "\(fileName).\(format.fileExtension)"
    }
    
    func findOptimalQuality(
        for image: CGImage,
        targetSizeKB: Int,
        format: ImageFormat = .jpeg,
        tolerance: Double = 0.1
    ) throws -> Double {
        guard format.supportsQuality else {
            throw ProcessingError.unsupportedFormat("Format \(format.rawValue) doesn't support quality adjustment")
        }
        
        guard format.isSupported else {
            throw ProcessingError.unsupportedFormat(format.rawValue)
        }
        
        let targetSizeBytes = targetSizeKB * 1024
        var minQuality = 0.1
        var maxQuality = 1.0
        var bestQuality = 0.9
        
        for _ in 0..<10 {
            let midQuality = (minQuality + maxQuality) / 2
            let options = ImageOptions(format: format, quality: midQuality)
            let size = try estimateFileSize(image, options: options)
            
            if Double(size) < Double(targetSizeBytes) * (1 - tolerance) {
                minQuality = midQuality
            } else if Double(size) > Double(targetSizeBytes) * (1 + tolerance) {
                maxQuality = midQuality
            } else {
                bestQuality = midQuality
                break
            }
            
            bestQuality = midQuality
        }
        
        return bestQuality
    }
    
    func getImageDimensions(_ image: CGImage) -> (width: Int, height: Int) {
        return (width: image.width, height: image.height)
    }
    
    func calculateNewDimensions(originalWidth: Int, originalHeight: Int, mode: ResizeMode) -> (width: Int, height: Int) {
        let aspectRatio = Double(originalWidth) / Double(originalHeight)
        var newWidth: Double
        var newHeight: Double
        
        switch mode {
        case .exact(let width, let height):
            return (width: width, height: height)
        case .fit(let maxWidth, let maxHeight):
            let maxAspectRatio = Double(maxWidth) / Double(maxHeight)
            if aspectRatio > maxAspectRatio {
                newWidth = Double(maxWidth)
                newHeight = newWidth / aspectRatio
            } else {
                newHeight = Double(maxHeight)
                newWidth = newHeight * aspectRatio
            }
        case .fill(let width, let height):
            return (width: width, height: height)
        case .scale(let factor):
            newWidth = Double(originalWidth) * factor
            newHeight = Double(originalHeight) * factor
        case .width(let width):
            newWidth = Double(width)
            newHeight = newWidth / aspectRatio
        case .height(let height):
            newHeight = Double(height)
            newWidth = newHeight * aspectRatio
        }
        
        return (width: Int(newWidth), height: Int(newHeight))
    }
    
    private func createImageProperties(for options: ImageOptions) -> [String: Any]? {
        guard options.format.supportsQuality else {
            return nil
        }
        
        var properties: [String: Any] = [:]
        
        switch options.format {
        case .jpeg, .jpg:
            properties[kCGImageDestinationLossyCompressionQuality as String] = options.quality
        case .heic:
            properties[kCGImageDestinationLossyCompressionQuality as String] = options.quality
        case .png:
            return nil
        }
        
        properties[kCGImageDestinationOptimizeColorForSharing as String] = true
        return properties
    }
}

extension ImageProcessor {
    func saveAsPNG(_ image: CGImage, to url: URL) throws {
        try saveImage(image, to: url, options: .defaultPNG)
    }
    
    func saveAsJPEG(_ image: CGImage, to url: URL, quality: Double = 0.9) throws {
        try saveImage(image, to: url, options: ImageOptions(format: .jpeg, quality: quality))
    }
    
    func saveAsHEIC(_ image: CGImage, to url: URL, quality: Double = 0.9) throws {
        try saveImage(image, to: url, options: ImageOptions(format: .heic, quality: quality))
    }
    
    static func supportedFormats() -> [ImageFormat] {
        return ImageFormat.allCases.filter { $0.isSupported }
    }
}
