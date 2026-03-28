//
//  Logger.swift
//  Scanner
//

import Foundation

enum LogLevel: String {
    case debug   = "[DEBUG]"
    case info    = "[INFO]"
    case warning = "[WARN]"
    case error   = "[ERROR]"
}

final class Logger {
    static let shared = Logger()

    #if DEBUG
    var isEnabled = true
    #else
    var isEnabled = false
    #endif

    private init() {}

    func log(
        _ message: @autoclosure () -> String,
        level: LogLevel = .debug,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isEnabled else { return }
        let fileName = (file as NSString).lastPathComponent
        print("\(level.rawValue) [\(fileName):\(line)] \(function) - \(message())")
    }
}
