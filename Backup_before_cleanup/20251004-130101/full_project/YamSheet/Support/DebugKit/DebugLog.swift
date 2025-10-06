//
//  DebugLog.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 30/09/2025.
//

#if DEBUG
import Foundation

func DLog(_ message: @autoclosure () -> String,
          file: StaticString = #fileID,
          function: StaticString = #function,
          line: UInt = #line) {
    guard DebugConfig.verboseLogs else { return }
    print("🔹[DEBUG] \(file):\(line) \(function) — \(message())")
}
#endif
