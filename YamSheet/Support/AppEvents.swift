//
//  AppEvents.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 10/09/2025.
//

import Foundation

extension Notification.Name {
    /// À poster quand GameDetailView doit fermer toute la pile et revenir à la liste
    static let closeToGamesList = Notification.Name("closeToGamesList")

    /// Demande à la liste des parties d'ouvrir directement une partie donnée.
    static let openGameFromList = Notification.Name("openGameFromList")
}
