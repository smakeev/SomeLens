import SwiftUI

struct LensContainerSizeKey: EnvironmentKey {
    static let defaultValue: CGSize = .zero
}

struct LensContainerSafeAreaInsetsKey: EnvironmentKey {
    static let defaultValue: EdgeInsets = EdgeInsets()
}

extension EnvironmentValues {
    var lensContainerSize: CGSize {
        get { self[LensContainerSizeKey.self] }
        set { self[LensContainerSizeKey.self] = newValue }
    }

    var lensContainerSafeAreaInsets: EdgeInsets {
        get { self[LensContainerSafeAreaInsetsKey.self] }
        set { self[LensContainerSafeAreaInsetsKey.self] = newValue }
    }

}
