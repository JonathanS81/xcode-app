//
//  Game+TurnEngine.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 03/09/2025.
//

import Foundation

extension Game {
    // Joueur actif (uniquement si la partie est en cours)
    var activePlayerID: UUID? {
        guard statusOrDefault == .inProgress,
              !turnOrder.isEmpty,
              currentTurnIndex < turnOrder.count else { return nil }
        return turnOrder[currentTurnIndex]
    }

    func isActive(playerID: UUID) -> Bool {
        activePlayerID == playerID
    }

    // Configuration de l'ordre (aléatoire ou manuel)
    func setTurnOrder(_ ids: [UUID]) {
        // Filtre de sécurité : si participantIDs est défini, on ne garde que ces IDs-là
        let valid: [UUID]
        if !participantIDs.isEmpty {
            let allowed = Set(participantIDs)
            valid = ids.filter { allowed.contains($0) }
        } else {
            valid = ids
        }

        turnOrder = valid
        currentTurnIndex = 0
        lastFilledCountByPlayer = [:]
        statusOrDefault = .inProgress
        startedAt = Date()
        endedAt = nil
    }

    // Figer les notations (13…15 requises selon options, bonus en optionnel)
    func configureNotations(required: [String], optional: [String]) {
        requiredNotationKeys = required
        optionalNotationKeys = optional
    }

    // Toutes les cases saisissables (pour la validation "1 case")
    var allFillableKeys: [String] { requiredNotationKeys + optionalNotationKeys }

    // Snapshot du début de tour
    func beginTurnSnapshot(for playerID: UUID, fillableCount: Int) {
        if lastFilledCountByPlayer[playerID] == nil {
            lastFilledCountByPlayer[playerID] = fillableCount
        }
    }

    // Valider "exactement 1 case" saisie durant le tour
    func canEndTurn(for playerID: UUID, fillableCount: Int) -> Bool {
        let start = lastFilledCountByPlayer[playerID] ?? fillableCount
        return (fillableCount - start) == 1
    }

    // Commit de fin de tour
    func endTurnCommit(for playerID: UUID, fillableCount: Int) {
        lastFilledCountByPlayer[playerID] = fillableCount
    }

    // Joueur suivant
    func advanceToNextPlayer() {
        guard !turnOrder.isEmpty else { return }
        currentTurnIndex = (currentTurnIndex + 1) % turnOrder.count
    }

    // Fin de partie: toutes les REQUISES sont remplies
    func completeIfFinished(requiredCellsPerPlayer: Int,
                            filledCount: (UUID) -> Int) -> Bool {
        let allDone = turnOrder.allSatisfy { pid in
            filledCount(pid) >= requiredCellsPerPlayer
        }
        if allDone {
            statusOrDefault = .completed
            endedAt = Date()
        }
        return allDone
    }
}

// MARK: - Jump direct vers un joueur
extension Game {
    /// Rend actif ce joueur immédiatement (ne change pas l'ordre).
    func jumpTo(playerID pid: UUID) {
        guard let idx = turnOrder.firstIndex(of: pid) else { return }
        self.currentTurnIndex = idx   // ← adapte le nom si ta propriété s'appelle autrement
    }
}

