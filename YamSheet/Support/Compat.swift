//
//  Compat.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 11/09/2025.
//

import SwiftUI

extension View {
    @ViewBuilder
    func onChangeCompat<T: Equatable>(_ value: T, perform: @escaping () -> Void) -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: value) { _, _ in perform() }
        } else {
            self.onChange(of: value) { _ in perform() }
        }
    }
}
