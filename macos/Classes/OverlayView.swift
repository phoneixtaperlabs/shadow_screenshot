import SwiftUI

struct OverlayView: View {
    let appName: String
    let windowTitle: String
    let autoCloseIn: TimeInterval
    let onClose: () -> Void
    
    @State private var timeRemaining: TimeInterval
    @State private var timer: Timer?
    
    private var progress: CGFloat {
        guard autoCloseIn > 0 else { return 0 }
        return max(0, min(1, timeRemaining / autoCloseIn))
    }
    
    init(appName: String, windowTitle: String, autoCloseIn: TimeInterval, onClose: @escaping () -> Void) {
        self.appName = appName
        self.windowTitle = windowTitle
        self.autoCloseIn = autoCloseIn
        self.onClose = onClose
        self._timeRemaining = State(initialValue: autoCloseIn)
    }
    
    var body: some View {
        ZStack {
            // Semi-transparent overlay
            Color.brandSecondary.opacity(0.1)
                .ignoresSafeArea()
            
            // Border around the window
            Rectangle()
                .stroke(Color.brandSecondary, lineWidth: 3)
                .ignoresSafeArea()
            
            // App information - centered horizontally and positioned 30% from top
            GeometryReader { geometry in
                HStack(spacing: 8) {
                    if let icon = ShadowScreenshotPlugin.shadowIconImage {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                    } else {
                        // 로딩 실패 시 보여줄 대체 이미지 (예: SF Symbol)
                        Image(systemName: "questionmark.circle")
                    }
                    Text("I'm currently viewing this screen.")
                        .foregroundStyle(Color.text0)
                }
                .padding(.horizontal, 12)     // Only horizontal padding
                .padding(.vertical, 10)
  /*              .padding(8)   */                                        // Internal padding
//                .frame(width: 280, height: 44)                        // Size first
                .background(Color.backgroundAppBody.opacity(0.9))     // Background fills the frame
                .cornerRadius(8)                                      // Rounded corners
                .overlay(                                             // Add border overlay
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.brandSecondary, lineWidth: 0.5)     // Orange border, 2pt thick
                )
                .position(
                    x: geometry.size.width / 2,
                    y: geometry.size.height * 0.15
                )
                
                
//                VStack(alignment: .leading, spacing: 4) {
//                    Label(appName, systemImage: "app.fill")
//                        .font(.headline)
//                        .foregroundColor(.white)
//                    
//                    if !windowTitle.isEmpty {
//                        Text(windowTitle)
//                            .font(.caption)
//                            .foregroundColor(.white.opacity(0.8))
//                            .lineLimit(1)
//                    }
//                    
//                    // Countdown timer
//                    Text("Closing in: \(Int(ceil(timeRemaining)))s")
//                        .font(.caption)
//                        .foregroundColor(.yellow)
//                }
//                .padding(10)
//                .background(Color.backgroundAppBody.opacity(0.9))
//                .cornerRadius(8)
//                .position(
//                    x: geometry.size.width / 2,
//                    y: geometry.size.height * 0.15
//                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startCountdown()
        }
        .onDisappear {
            // Clean up timer when view disappears
            timer?.invalidate()
            timer = nil
            print("TargetedOverlayView disappeared and cleaned up")
        }
    }
    
    private func startCountdown() {
        // Only start the timer if there is a duration
        guard autoCloseIn > 0 else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 0.1
            } else {
                // Ensure it's exactly 0 at the end
                timeRemaining = 0
                timer?.invalidate()
                timer = nil
            }
        }
    }
}

//import SwiftUI
//
//struct OverlayView: View {
//    let appName: String
//    let windowTitle: String
//    let autoCloseIn: TimeInterval
//    let onClose: () -> Void
//    
//    @State private var timeRemaining: TimeInterval
//    @State private var timer: Timer?
//    
//    private var progress: CGFloat {
//        guard autoCloseIn > 0 else { return 0 }
//        return max(0, min(1, timeRemaining / autoCloseIn))
//    }
//    
//    init(appName: String, windowTitle: String, autoCloseIn: TimeInterval, onClose: @escaping () -> Void) {
//        self.appName = appName
//        self.windowTitle = windowTitle
//        self.autoCloseIn = autoCloseIn
//        self.onClose = onClose
//        self._timeRemaining = State(initialValue: autoCloseIn)
//    }
//    
//    var body: some View {
//        ZStack {
//            // Semi-transparent overlay
//            Color.orange.opacity(0.1)
//                .ignoresSafeArea()
//            
//            // Border around the window
//            Rectangle()
//                .stroke(Color.orange, lineWidth: 3)
//                .ignoresSafeArea()
//            
//            // App information
//            VStack {
//                HStack {
//                    VStack(alignment: .leading, spacing: 4) {
//                        Label(appName, systemImage: "app.fill")
//                            .font(.headline)
//                            .foregroundColor(.white)
//                        
//                        if !windowTitle.isEmpty {
//                            Text(windowTitle)
//                                .font(.caption)
//                                .foregroundColor(.white.opacity(0.8))
//                                .lineLimit(1)
//                        }
//                        
//                        // Countdown timer
//                        Text("Closing in: \(Int(ceil(timeRemaining)))s") // Use ceil to avoid showing 0s too early
//                            .font(.caption)
//                            .foregroundColor(.yellow)
//                    }
//                    .padding(10)
//                    .background(Color.purple.opacity(0.9))
//                    .cornerRadius(8)
//                    
//                    Spacer()
//                    
////                    Button(action: {
////                        onClose()
////                    }) {
////                        Image(systemName: "xmark.circle.fill")
////                            .font(.title2)
////                            .foregroundColor(.white)
////                    }
////                    .buttonStyle(PlainButtonStyle())
////                    .padding(10)
//                }
//                .padding()
//                
//                Spacer()
//                
//                // Progress bar showing time remaining
////                GeometryReader { geometry in
////                    ZStack(alignment: .leading) {
////                        Rectangle()
////                            .fill(Color.white.opacity(0.2))
////                            .frame(height: 4)
////                        
////                        Rectangle()
////                            .fill(Color.yellow)
////                            // UPDATED: Use the safe 'progress' property
////                            .frame(width: geometry.size.width * progress, height: 4)
////                            .animation(.linear(duration: 0.1), value: timeRemaining)
////                    }
////                }
////                .frame(height: 4)
////                .padding(.horizontal)
////                .padding(.bottom, 20)
//            }
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .onAppear {
//            startCountdown()
//        }
//        .onDisappear {
//            // Clean up timer when view disappears
//            timer?.invalidate()
//            timer = nil
//            print("TargetedOverlayView disappeared and cleaned up")
//        }
//    }
//    
//    private func startCountdown() {
//        // Only start the timer if there is a duration
//        guard autoCloseIn > 0 else { return }
//        
//        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
//            if timeRemaining > 0 {
//                timeRemaining -= 0.1
//            } else {
//                // Ensure it's exactly 0 at the end
//                timeRemaining = 0
//                timer?.invalidate()
//                timer = nil
//            }
//        }
//    }
//}
