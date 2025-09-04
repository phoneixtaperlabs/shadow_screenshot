import Cocoa
import FlutterMacOS

public class ShadowScreenshotPlugin: NSObject, FlutterPlugin {
    
    public static var shadowIconImage: NSImage?
    
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
        
        loadShadowIcon(registrar: registrar)
    }
    
    private static func loadShadowIcon(registrar: FlutterPluginRegistrar) {
        let assetPath = "assets/images/icons/shadow.svg"
        let assetKey = registrar.lookupKey(forAsset: assetPath)
        
        // ❌ 이전의 잘못된 코드
        // guard let filePath = Bundle.main.path(forResource: assetKey, ofType: nil) else { ... }
        
        // ✅ 수정된 올바른 코드
        // 앱 번들의 기본 경로와 assetKey를 직접 조합하여 전체 파일 경로를 생성합니다.
        let bundlePath = Bundle.main.bundlePath
        let filePath = (bundlePath as NSString).appendingPathComponent(assetKey)
        
        // 파일이 실제로 존재하는지 확인하는 것이 좋습니다.
        guard FileManager.default.fileExists(atPath: filePath) else {
            print("❌ ERROR: File does not exist at constructed path: \(filePath)")
            return
        }
        
        do {
            // 이제 이 filePath를 사용해 데이터를 읽습니다.
            let fileUrl = URL(fileURLWithPath: filePath)
            let data = try Data(contentsOf: fileUrl)
            self.shadowIconImage = NSImage(data: data)
            print("✅ SVG icon 'shadow.svg' loaded as NSImage.")
        } catch {
            print("❌ ERROR: Failed to create NSImage from SVG asset: \(error)")
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
