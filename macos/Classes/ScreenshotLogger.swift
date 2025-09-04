import Foundation
import os.log

// MARK: - ScreenshotLogger Actor
actor ScreenshotLogger {
    // MARK: - Singleton
    @MainActor private static var _shared: ScreenshotLogger?
    
    @MainActor static var shared: ScreenshotLogger {
        get async {
            if let logger = _shared {
                return logger
            }
            fatalError("ScreenshotLogger.configure() must be called before accessing ScreenshotLogger.shared")
        }
    }
    
    // MARK: - Configuration
    @MainActor
    static func configure(subsystem: String,
                          category: String,
                          logDirectory: URL? = nil,
                          retentionDays: Int = 30,
                          minimumLogLevel: LogType = .debug) {
        if _shared == nil {
            _shared = ScreenshotLogger(subsystem: subsystem,
                                       category: category,
                                       logDirectory: logDirectory,
                                       retentionDays: retentionDays,
                                       minimumLogLevel: minimumLogLevel)
        } else {
            print("Warning: ScreenshotLogger already configured. Configuration can only be set once at startup.")
        }
    }
    
    // MARK: - Properties
    private let osLog: OSLog
    private let logDirectory: URL
    private var currentLogFileURL: URL?
    private var logFileHandle: FileHandle?
    private let dateFormatter: DateFormatter
    private let timestampFormatter: DateFormatter
    private let iso8601Formatter: ISO8601DateFormatter
    private let retentionDays: Int
    
    // Current date tracking for rotation
    private var currentLogDate: String = ""
    
    // Log level configuration
    private(set) var minimumLogLevel: LogType
    
    // Log levels
    enum LogType: String, Comparable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            }
        }
        
        static func < (lhs: LogType, rhs: LogType) -> Bool {
            let order: [LogType] = [.debug, .info, .warning, .error]
            guard let lhsIndex = order.firstIndex(of: lhs),
                  let rhsIndex = order.firstIndex(of: rhs) else {
                return false
            }
            return lhsIndex < rhsIndex
        }
    }
    
    // MARK: - Initialization
    private init(subsystem: String,
                 category: String,
                 logDirectory: URL? = nil,
                 retentionDays: Int = 7,
                 minimumLogLevel: LogType = .debug) {
        
        // Initialize OSLog
        self.osLog = OSLog(subsystem: subsystem, category: category)
        
        // Set log level
        self.minimumLogLevel = minimumLogLevel
        
        // Set retention period
        self.retentionDays = retentionDays
        
        // Initialize date formatters
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd"
        self.dateFormatter.timeZone = TimeZone.current
        
        self.timestampFormatter = DateFormatter()
        self.timestampFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        self.timestampFormatter.timeZone = TimeZone.current
        
        self.iso8601Formatter = ISO8601DateFormatter()
        
        // Setup log directory
        let fileManager = FileManager.default
        if let customLogDirectory = logDirectory {
            self.logDirectory = customLogDirectory
        } else {
            self.logDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("com.taperlabs.shadow", isDirectory: true)
                .appendingPathComponent("logs", isDirectory: true)
        }
        
        // Create logs directory if it doesn't exist
        do {
            try fileManager.createDirectory(at: self.logDirectory, withIntermediateDirectories: true)
        } catch {
            print("Failed to create log directory: \(error)")
        }
        
        // Initialize with current date
        self.currentLogDate = self.dateFormatter.string(from: Date())
        
        // actor가 완전히 초기화된 후, 비동기 Task로 파일 관련 작업을 수행합니다.
        Task {
            await self.setupLogFile()
            await self.cleanupOldLogFiles()
            
            // 초기화 로그도 이 Task 안에서 함께 처리할 수 있습니다.
            await self.logInternal(message: "ScreenshotLogger initialized with subsystem: \(subsystem), category: \(category), minimumLogLevel: \(minimumLogLevel.rawValue), retentionDays: \(retentionDays)",
                                   type: .info, file: #file, function: #function, line: #line)
        }
    }
    
    deinit {
        // Clean up resources
        try? self.logFileHandle?.close()
        self.logFileHandle = nil
        
        // Log deinitialization (this might not write due to closed handle)
        os_log("ScreenshotLogger deinitialized", log: self.osLog, type: .info)
    }
    
    // MARK: - Public Methods (Actor-isolated)
    
    /// Update minimum log level
    func updateMinimumLogLevel(_ level: LogType) {
        minimumLogLevel = level
        Task {
            logInternal(message: "Minimum log level changed to: \(level.rawValue)",
                        type: .info, file: #file, function: #function, line: #line)
        }
    }
    
    /// Force manual log rotation (useful for testing or manual rotation)
    func forceRotateLogFile() {
        rotateLogFileIfNeeded(force: true)
    }
    
    /// Internal log method (actor-isolated)
    private func logInternal(message: String,
                             type: LogType,
                             file: String,
                             function: String,
                             line: Int) {
        
        // Skip logging if below minimum log level
        guard type >= minimumLogLevel else {
            return
        }
        
        // Log to OSLog
        os_log("%{public}@", log: self.osLog, type: type.osLogType, message)
        
        // Write to file
        writeToFile(message: message, type: type, file: file, function: function, line: line)
    }
    
    // MARK: - Non-isolated Public Methods (for synchronous API)
    
    /// Log a message with a specific log level and source location information
    nonisolated func log(message: String,
                         type: LogType,
                         file: String = #file,
                         function: String = #function,
                         line: Int = #line) {
        Task {
            await logInternal(message: message, type: type, file: file, function: function, line: line)
        }
    }
    
    /// Convenience methods for different log levels with source location
    nonisolated func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message: message, type: .debug, file: file, function: function, line: line)
    }
    
    nonisolated func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message: message, type: .info, file: file, function: function, line: line)
    }
    
    nonisolated func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message: message, type: .warning, file: file, function: function, line: line)
    }
    
    nonisolated func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message: message, type: .error, file: file, function: function, line: line)
    }
    
    // MARK: - Private Methods (Actor-isolated)
    
    private func writeToFile(message: String, type: LogType, file: String, function: String, line: Int, isRetry: Bool = false) {
        // Check if we need to rotate first (this handles day changes)
        rotateLogFileIfNeeded()
        
        guard let logFileHandle = self.logFileHandle else {
            print("Log file handle is nil, attempting to recreate")
            setupLogFile()
            guard self.logFileHandle != nil else {
                print("Failed to recreate log file handle")
                return
            }
            // Retry writing after recreation
            writeToFile(message: message, type: type, file: file, function: function, line: line, isRetry: true)
            return
        }
        
        // Extract filename from path
        let filename = URL(fileURLWithPath: file).lastPathComponent
        
        // Format log entry
        let utcTimestamp = iso8601Formatter.string(from: Date())
        let localTimestamp = timestampFormatter.string(from: Date())
        let threadID = Thread.current.hashValue
        
        let logEntry = "[UTC: \(utcTimestamp)] [LOCAL: \(localTimestamp)] [\(type.rawValue)] [Thread: \(threadID)] [\(function)] \(message)\n"
        
        // Write to file with proper error handling
        guard let data = logEntry.data(using: .utf8) else {
            print("Failed to encode log entry to UTF-8")
            return
        }
        
        do {
            try logFileHandle.write(contentsOf: data)
            try logFileHandle.synchronize()
        } catch {
            print("Failed to write to log file: \(error)")
            // Attempt to recreate file handle
            setupLogFile()
        }
    }
    
    private func setupLogFile() {
        // Close existing handle
        try? logFileHandle?.close()
        logFileHandle = nil
        
        // Create log file URL for current date
        let logFileName = "\(currentLogDate)-screenshot.log"
        currentLogFileURL = logDirectory.appendingPathComponent(logFileName)
        
        guard let logFileURL = currentLogFileURL else {
            print("Failed to create log file URL")
            return
        }
        
        let fileManager = FileManager.default
        
        // Create log file if it doesn't exist
        let fileExists = fileManager.fileExists(atPath: logFileURL.path)
        if !fileExists {
            let success = fileManager.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
            if !success {
                print("Failed to create log file at path: \(logFileURL.path)")
                return
            }
        }
        
        // Open file handle for writing
        do {
            logFileHandle = try FileHandle(forWritingTo: logFileURL)
            logFileHandle?.seekToEndOfFile()
            
            // Write header if this is a new file
            if !fileExists || logFileHandle?.offsetInFile == 0 {
                let header = "--- Screenshot Module Log File: \(currentLogDate) ---\n"
                if let headerData = header.data(using: .utf8) {
                    try logFileHandle?.write(contentsOf: headerData)
                }
            }
        } catch {
            print("Failed to open log file: \(error)")
            logFileHandle = nil
        }
    }
    
    private func rotateLogFileIfNeeded(force: Bool = false) {
        let today = dateFormatter.string(from: Date())
        
        // Check if we need to rotate (new day or force)
        if today != currentLogDate || force {
            let previousDate = currentLogDate
            currentLogDate = today
            
            print("Rotating log file from \(previousDate) to \(today)")
            
            // Setup new log file
            setupLogFile()
            
            // Clean up old files
            cleanupOldLogFiles()
        }
    }
    
    private func cleanupOldLogFiles() {
        let fileManager = FileManager.default
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: nil)
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date())!
            
            // DateFormatter는 파일 이름 파싱용으로 재사용
            let fileDateFormatter = DateFormatter()
            fileDateFormatter.dateFormat = "yyyy-MM-dd"
            
            for fileURL in fileURLs where fileURL.pathExtension == "log" {
                // 파일 이름에서 날짜 부분 추출 (e.g., "2025-08-26")
                let fileName = fileURL.deletingPathExtension().lastPathComponent
                let dateString = String(fileName.split(separator: "-").prefix(3).joined(separator: "-"))
                
                if let fileDate = fileDateFormatter.date(from: dateString) {
                    if fileDate < cutoffDate {
                        do {
                            try fileManager.removeItem(at: fileURL)
                            print("Deleted old log file: \(fileURL.lastPathComponent)")
                        } catch {
                            print("Failed to delete old log file \(fileURL.lastPathComponent): \(error)")
                        }
                    }
                }
            }
        } catch {
            print("Failed to cleanup old log files: \(error)")
        }
    }
}

