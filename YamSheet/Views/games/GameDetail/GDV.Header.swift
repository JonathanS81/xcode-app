//
//  GDV.Header.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 14/09/2025.
//
import SwiftUI

struct GDV_Header: View {
    let title: String
    let subtitle: String?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title3.weight(.semibold))
                if let subtitle {
                    Text(subtitle).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
