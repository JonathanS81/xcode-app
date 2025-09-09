//
//  TurnRules.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 03/09/2025.
//
import Foundation

/// Compte le nombre de cases REMPLIES (requises + optionnelles) pour un joueur.
/// valueForKey doit retourner `nil` si la cellule est vide, sinon la valeur (Int).
func fillableCount(game: Game, playerID: UUID, valueForKey: (UUID, String) -> Int?) -> Int {
    game.allFillableKeys.reduce(0) { acc, key in
        acc + (valueForKey(playerID, key) == nil ? 0 : 1)
    }
}

/// Nombre de cases REQUISES par joueur (figées selon les options).
func requiredCellsPerPlayer(game: Game) -> Int {
    game.requiredNotationKeys.count
}

/// Test de fin de partie (toutes les REQUISES remplies pour tous).
func isGameCompleted(game: Game, valueForKey: (UUID, String) -> Int?) -> Bool {
    game.turnOrder.allSatisfy { pid in
        game.requiredNotationKeys.allSatisfy { key in valueForKey(pid, key) != nil }
    }
}

