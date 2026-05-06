//
//  LensApp.swift
//  Lens
//
//  Created by Sergey Makeev on 10.11.2025.
//

import SwiftUI
import OSLog
import SomeLens

@main
struct LensApp: App {
    init() {
        AppLoggingBootstrap.bootstrap()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

private enum AppLoggingBootstrap {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "someprojects.Lens",
        category: "Logging"
    )

    static func bootstrap() {
        // Demo app uses the system OSLog backend directly. SomeLens maps compact
        // logs to info and verbose diagnostics to debug inside its logging layer.
        SomeLensLogging.verbose()
        logger.info("SomeLens logging bootstrapped to OSLog with verbose diagnostics enabled")
    }
}
