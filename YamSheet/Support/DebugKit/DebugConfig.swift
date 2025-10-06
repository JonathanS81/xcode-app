//
//  DebugConfig.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 30/09/2025.
//

#if DEBUG
import Foundation

enum DebugKeys {
    static let debugMode   = "debugMode"       // ON/OFF global
    static let verboseLogs = "debugVerbose"    // logs verbeux via DLog
    static let autoSeed    = "debugAutoSeed"   // seed auto au lancement
}

enum DebugConfig {
    // Lecture des préférences (pilotées par Settings)
    static var isOn: Bool { UserDefaults.standard.bool(forKey: DebugKeys.debugMode) }
    static var verboseLogs: Bool { isOn && UserDefaults.standard.bool(forKey: DebugKeys.verboseLogs) }
    static var autoSeedOnLaunch: Bool { isOn && UserDefaults.standard.bool(forKey: DebugKeys.autoSeed) }
}
#endif
