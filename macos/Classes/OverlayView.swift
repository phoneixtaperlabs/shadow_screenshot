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
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            // Border around the window
            Rectangle()
                .stroke(Color.red, lineWidth: 3)
                .ignoresSafeArea()
            
            // App information
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(appName, systemImage: "app.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if !windowTitle.isEmpty {
                            Text(windowTitle)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(1)
                        }
                        
                        // Countdown timer
                        Text("Closing in: \(Int(ceil(timeRemaining)))s") // Use ceil to avoid showing 0s too early
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                    .padding(10)
                    .background(Color.purple.opacity(0.9))
                    .cornerRadius(8)
                    
                    Spacer()
                    
//                    Button(action: {
//                        onClose()
//                    }) {
//                        Image(systemName: "xmark.circle.fill")
//                            .font(.title2)
//                            .foregroundColor(.white)
//                    }
//                    .buttonStyle(PlainButtonStyle())
//                    .padding(10)
                }
                .padding()
                
                Spacer()
                
                // Progress bar showing time remaining
//                GeometryReader { geometry in
//                    ZStack(alignment: .leading) {
//                        Rectangle()
//                            .fill(Color.white.opacity(0.2))
//                            .frame(height: 4)
//                        
//                        Rectangle()
//                            .fill(Color.yellow)
//                            // UPDATED: Use the safe 'progress' property
//                            .frame(width: geometry.size.width * progress, height: 4)
//                            .animation(.linear(duration: 0.1), value: timeRemaining)
//                    }
//                }
//                .frame(height: 4)
//                .padding(.horizontal)
//                .padding(.bottom, 20)
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
