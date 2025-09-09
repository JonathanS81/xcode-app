//
//  ConfettiView.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 06/09/2025.
//

import SwiftUI

struct ConfettiView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        DispatchQueue.main.async {
            let layer = CAEmitterLayer()
            layer.emitterPosition = CGPoint(x: v.bounds.midX, y: -10)
            layer.emitterShape = .line
            layer.emitterSize = CGSize(width: v.bounds.width, height: 1)

            func cell(_ color: UIColor, _ img: UIImage?) -> CAEmitterCell {
                let c = CAEmitterCell()
                c.birthRate = 8
                c.lifetime = 6
                c.velocity = 180
                c.velocityRange = 80
                c.emissionLongitude = .pi
                c.emissionRange = .pi / 6
                c.spin = 3.5
                c.spinRange = 2.0
                c.scale = 0.6
                c.scaleRange = 0.3
                c.color = color.cgColor
                c.contents = (img ?? UIImage(systemName: "circle.fill"))?.cgImage
                return c
            }

            let colors: [UIColor] = [.systemPink, .systemYellow, .systemGreen, .systemBlue, .systemPurple, .systemOrange]
            let imgs: [UIImage?] = [UIImage(systemName: "suit.heart.fill"),
                                    UIImage(systemName: "suit.club.fill"),
                                    UIImage(systemName: "suit.diamond.fill"),
                                    UIImage(systemName: "suit.spade.fill")]
            layer.emitterCells = (0..<14).map { i in
                cell(colors[i % colors.count], imgs[i % imgs.count])
            }

            v.layer.addSublayer(layer)
            // Arrêt automatique après 2,5s
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                layer.birthRate = 0
            }
        }
        return v
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
