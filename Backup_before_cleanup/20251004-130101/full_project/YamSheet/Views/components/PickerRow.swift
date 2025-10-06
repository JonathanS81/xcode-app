//
//  PickerRow.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 14/09/2025.
//

import SwiftUI

public struct PickerRow: View {
    let label: String
    let values: [Int]
    @Binding var selection: Int
    let valueToText: (Int) -> String

    public init(label: String, values: [Int], selection: Binding<Int>, valueToText: @escaping (Int) -> String) {
        self.label = label
        self.values = values
        self._selection = selection
        self.valueToText = valueToText
    }

    public var body: some View {
        HStack {
            Text(label).frame(width: 110, alignment: .leading)
            Menu {
                Picker("Valeur", selection: $selection) {
                    ForEach(values, id: \.self) { v in
                        Text(valueToText(v)).tag(v)
                    }
                }
            } label: {
                Text(valueToText(selection))
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color.gray.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
