//
//  DebugLog.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 30/09/2025.
//

#if DEBUG
import Foundation

/// Logger debug tolérant (comme `print`) — accepte plusieurs items.
/// Exemple: DLog("[Lottie] chargeables =", ok)
func DLog(_ items: Any...,
          separator: String = " ",
          file: StaticString = #fileID,
          function: StaticString = #function,
          line: UInt = #line) {
    guard DebugConfig.verboseLogs else { return }
    let msg = items.map { String(describing: $0) }.joined(separator: separator)
    print("🔹[DEBUG] \(file):\(line) \(function) — \(msg)")
}
#endif
