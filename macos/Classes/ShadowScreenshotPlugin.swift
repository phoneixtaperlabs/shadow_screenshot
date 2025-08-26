import Cocoa
import FlutterMacOS

public class ShadowScreenshotPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "shadow_screenshot", binaryMessenger: registrar.messenger)
        let instance = ShadowScreenshotPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        let eventChannel = FlutterEventChannel(name: "shadow_screenshot_events", binaryMessenger: registrar.messenger)
        
        // Task를 사용하여 모든 비동기 초기화 작업을 안전하게 처리
        Task { @MainActor in
            // 1. 로거를 먼저 설정
            ScreenshotLogger.configure(
                subsystem: "com.taperlabs.shadow",
                category: "screenshot",
                retentionDays: 7,
                minimumLogLevel: .debug
            )
            // 4. 모든 준비가 끝난 후 핸들러를 설정
            eventChannel.setStreamHandler(ScreenshotEventManager.shared)
        }
    }
    
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
            
        case "screenshot":
            let service = ScreenCaptureKitService()
            Task {
                // Save as thumbnail
                let _ = try await service.saveScreenshot(
                    fileName: "thumb",
                    imageOptions: .thumbnailJPEG
                )
                
                // Resize to HD (1920x1080)
                let _ = try await service.saveScreenshot(
                    fileName: "HD_image",
                    imageOptions: ImageProcessor.ImageOptions(
                        format: .jpeg,
                        quality: 0.9,
                        resize: .exact(width: 1920, height: 1080)
                    )
                )
                
                // Scale to 50% of original size
                let _ = try await service.saveScreenshot(
                    fileName: "half_sie_image",
                    imageOptions: ImageProcessor.ImageOptions(
                        format: .jpeg,
                        quality: 0.9,
                        resize: .scale(factor: 0.5)
                    )
                )
            }
            
            result("Screenshot")
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
