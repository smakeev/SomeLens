#if os(iOS)
import UIKit

typealias SomeLensPlatformImage = UIImage
#elseif os(macOS)
import AppKit

typealias SomeLensPlatformImage = NSImage
#endif
