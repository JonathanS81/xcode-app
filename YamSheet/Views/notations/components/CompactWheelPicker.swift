//
//  CompactWheelPicker.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 28/08/2025.
//
import SwiftUI

struct CompactWheelPicker: View {
    @Binding var value: Int
    let range: [Int]
    let title: String
    var display: (Int) -> String = { "\($0)" }
    var width: CGFloat = 110
    var panelWidth: CGFloat = 320
    var panelHeight: CGFloat = 260

    @State private var showing = false

    init(value: Binding<Int>,
         range: ClosedRange<Int>,
         title: String,
         display: @escaping (Int)->String = { "\($0)" },
         width: CGFloat = 110,
         panelWidth: CGFloat = 320,
         panelHeight: CGFloat = 260) {
        self._value = value
        self.range = Array(range)
        self.title = title
        self.display = display
        self.width = width
        self.panelWidth = panelWidth
        self.panelHeight = panelHeight
    }

    var body: some View {
        Button {
            showing = true
        } label: {
            Text(display(value))
                .font(.body.monospacedDigit())
                .frame(minWidth: width)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showing) {
            ZStack {
                // fond cliquable pour fermer (léger voile)
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture { showing = false }

                // petit panneau centré
                VStack(spacing: 12) {
                    Text(title).font(.headline)
                    Picker(title, selection: $value) {
                        ForEach(range, id:\.self) { v in
                            Text(display(v)).tag(v)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.wheel)
                    .frame(height: panelHeight - 100)

                    HStack(spacing: 12) {
                        Button("Annuler") { showing = false }
                            .buttonStyle(.bordered)
                        Button("Terminer") { showing = false }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .frame(width: panelWidth, height: panelHeight)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(radius: 12)
            }
            // on garde le fond transparent (pas d’arrière-plan de sheet)
            .presentationBackground(.clear)
        }
    }
}
