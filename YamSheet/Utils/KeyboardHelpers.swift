//
//  KeyboardHelpers.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 01/09/2025.
//

import SwiftUI

public extension View {
    func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
        #endif
    }
}
