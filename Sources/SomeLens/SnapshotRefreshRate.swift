import Foundation

public enum SnapshotRefreshRate: Equatable {
    case never
    case automatic
    case fast
    case balanced
    case relaxed
    case slow
    case custom(milliseconds: Int)

    var interval: TimeInterval? {
        switch self {
        case .never:
            nil
        case .automatic:
            0.2
        case .fast:
            1.0 / 30.0
        case .balanced:
            0.1
        case .relaxed:
            0.25
        case .slow:
            0.5
        case .custom(let milliseconds):
            TimeInterval(max(milliseconds, 1)) / 1000.0
        }
    }
}
