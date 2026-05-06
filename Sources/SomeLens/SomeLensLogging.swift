import OSLog

public enum SomeLensLogging {
    public enum Level {
        case compact
        case verbose
    }

    public static var isEnabled = false
    public static var level: Level = .compact

    public static func compact() {
        isEnabled = true
        level = .compact
    }

    public static func verbose() {
        isEnabled = true
        level = .verbose
    }
}

protocol Loggable {
    var log: SomeLensLog.Scope { get }
}

extension Loggable {
    var d: SomeLensLog.Sink {
        log.d
    }

    var i: SomeLensLog.Sink {
        log.i
    }
}

enum SomeLensLog {
    struct Scope {
        let logger: Logger

        var d: Sink {
            Sink(logger: logger, level: .debug)
        }

        var i: Sink {
            Sink(logger: logger, level: .info)
        }
    }

    struct Sink {
        let logger: Logger
        let level: Level

        func callAsFunction(
            _ message: @autoclosure () -> String,
            fileID: StaticString = #fileID,
            function: StaticString = #function,
            line: UInt = #line
        ) {
            guard SomeLensLogging.isEnabled else { return }
            guard shouldEmit else { return }

            let location = "\(fileID):\(line) \(function)"
            let msg = message()
            switch level {
            case .info:
                logger.info("\(location, privacy: .public) \(msg, privacy: .public)")
            case .debug:
                logger.debug("\(location, privacy: .public) \(msg, privacy: .public)")
            }
        }

        private var shouldEmit: Bool {
            switch (SomeLensLogging.level, level) {
            case (.compact, .info):
                true
            case (.compact, .debug):
                false
            case (.verbose, .info), (.verbose, .debug):
                true
            }
        }
    }

    enum Level {
        case info
        case debug
    }

    static let container = Scope(logger: Logger(subsystem: "SomeLens", category: "LensContainer"))
    static let lens = Scope(logger: Logger(subsystem: "SomeLens", category: "GlassLens"))
    static let snapshot = Scope(logger: Logger(subsystem: "SomeLens", category: "SnapshotProvider"))
}
