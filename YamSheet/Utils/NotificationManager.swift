//
//  NotificationManager.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 06/09/2025.
//

import Foundation
import UserNotifications

enum NotificationManager {
    /// À appeler tôt (ex: onAppear d’un écran principal) pour demander l’autorisation.
    static func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        }
    }

    /// Déclenche une notif locale immédiate pour la fin de partie (si l’app est en arrière-plan).
    static func postEndGame(winnerName: String, gameName: String?, rankings: [(String, Int)]) {
        let content = UNMutableNotificationContent()
        content.title = "Partie terminée 🎉"
        //let gName = (gameName?.isEmpty == false) ? " «\(gameName!)»" : ""
        content.subtitle = "Bravo \(winnerName) !"
        let top3 = rankings.prefix(3)
            .enumerated()
            .map { "\($0.offset + 1). \($0.element.0) — \($0.element.1)" }
            .joined(separator: "   ")
        content.body = top3.isEmpty ? "Tou·te·s les scores sont enregistrés." : top3
        content.sound = .default

        let req = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // immédiat
        )
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }
}

