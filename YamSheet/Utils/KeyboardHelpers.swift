//
//  KeyboardHelpers.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 01/09/2025.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

public extension View {
    func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
        #endif
    }

    /// Ferme le clavier lorsqu'un tap a lieu en dehors d'un champ de saisie,
    /// sans intercepter les gestes des boutons, menus ou sélecteurs SwiftUI.
    @ViewBuilder
    func dismissKeyboardOnOutsideTap() -> some View {
        #if canImport(UIKit)
        background(KeyboardDismissTapInstaller())
        #else
        self
        #endif
    }
}

#if canImport(UIKit)
private struct KeyboardDismissTapInstaller: UIViewRepresentable {
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var installedWindow: UIWindow?

        private lazy var recognizer: UITapGestureRecognizer = {
            let recognizer = UITapGestureRecognizer(
                target: self,
                action: #selector(dismissKeyboard)
            )
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            return recognizer
        }()

        func install(on window: UIWindow?) {
            guard installedWindow !== window else { return }
            uninstall()
            guard let window else { return }
            window.addGestureRecognizer(recognizer)
            installedWindow = window
        }

        func uninstall() {
            installedWindow?.removeGestureRecognizer(recognizer)
            installedWindow = nil
        }

        @objc private func dismissKeyboard() {
            installedWindow?.endEditing(true)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            var touchedView = touch.view
            while let view = touchedView {
                if view is UITextField || view is UITextView {
                    return false
                }
                touchedView = view.superview
            }
            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        scheduleInstallation(for: view, coordinator: context.coordinator)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        scheduleInstallation(for: uiView, coordinator: context.coordinator)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    private func scheduleInstallation(for view: UIView, coordinator: Coordinator) {
        DispatchQueue.main.async {
            coordinator.install(on: view.window)
        }
    }
}
#endif
