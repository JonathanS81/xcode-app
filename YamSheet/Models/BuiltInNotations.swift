import Foundation
import SwiftData

enum BuiltInNotations {
    private static let retiredBuiltInIDs = ["yamsheet.yams-classic.v1"]

    static func installIfNeeded(in context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<Notation>())

        // Les notations personnelles déjà présentes avant la V2 n'avaient pas
        // encore de date de création. Elles reçoivent la référence V1 définie
        // pour assurer un classement stable lors des futurs imports.
        for notation in existing where notation.createdAt == nil && !notation.isBuiltIn {
            notation.createdAt = NotationCreationDatePolicy.legacyV1
        }

        // Nettoie uniquement le second modèle intégré du prototype V2.
        // Les notations personnelles portant un nom similaire ne sont jamais touchées.
        for notation in existing where retiredBuiltInIDs.contains(notation.builtInIdentifierRaw ?? "") {
            context.delete(notation)
        }

        if let installedStandard = existing.first(where: {
            $0.builtInIdentifierRaw == BuiltInNotationID.standard.rawValue
        }) {
            configureStandard(installedStandard)
        } else {
            context.insert(make(.standard))
        }
        try context.save()
    }

    static func make(_ identifier: BuiltInNotationID) -> Notation {
        switch identifier {
        case .standard:
            let notation = Notation(name: "Standard")
            configureStandard(notation)
            return notation
        }
    }

    private static func configureStandard(_ notation: Notation) {
        notation.name = "Standard"
        notation.comment = "Notation standard du Yahtzee"
        notation.tooltipUpper = "Additionnez uniquement les dés correspondant à la ligne. Un total d’au moins 63 points rapporte un bonus de 35 points."
        notation.tooltipMiddle = "La notation standard n’utilise pas de section Max / Min."
        notation.tooltipBottom = "Chaque combinaison peut être inscrite une seule fois. Si elle n’est pas réalisée, inscrivez 0."
        notation.upperBonusThreshold = 63
        notation.upperBonusValue = 35
        notation.middleMode = .multiplier
        notation.ruleBrelan = FigureRule(mode: .raw)
        notation.ruleChance = FigureRule(mode: .raw)
        notation.isChanceEnabled = true
        notation.ruleFull = FigureRule(mode: .fixed, fixedValue: 25)
        notation.ruleSuite = FigureRule(mode: .fixed, fixedValue: 40)
        notation.rulePetiteSuite = FigureRule(mode: .fixed, fixedValue: 30)
        notation.isSmallStraightEnabled = true
        notation.ruleCarre = FigureRule(mode: .raw)
        notation.ruleYams = FigureRule(mode: .fixed, fixedValue: 50)
        notation.extraYamsBonusValue = 100
        notation.builtInIdentifier = .standard
        notation.visibility = NotationVisibility(middleSectionEnabled: false)
        notation.suiteBigMode = .singleFixed
        notation.suiteBigFixed = 40
        notation.extraYamsBonusMode = .multiple
        notation.scoreHelpTexts = [
            ScoreHelpKey.sectionUpper.rawValue: "Additionnez uniquement les dés correspondant à la ligne. À partir de 63 points, ajoutez le bonus de 35 points.",
            ScoreHelpKey.ones.rawValue: "Additionnez tous les dés affichant 1.",
            ScoreHelpKey.twos.rawValue: "Additionnez tous les dés affichant 2.",
            ScoreHelpKey.threes.rawValue: "Additionnez tous les dés affichant 3.",
            ScoreHelpKey.fours.rawValue: "Additionnez tous les dés affichant 4.",
            ScoreHelpKey.fives.rawValue: "Additionnez tous les dés affichant 5.",
            ScoreHelpKey.sixes.rawValue: "Additionnez tous les dés affichant 6.",
            ScoreHelpKey.sectionMiddle.rawValue: "Cette section est masquée dans la notation standard.",
            ScoreHelpKey.sectionBottom.rawValue: "Réalisez la combinaison indiquée, puis saisissez son score. Une combinaison manquée vaut 0.",
            ScoreHelpKey.brelan.rawValue: "Au moins trois dés identiques. Le score correspond à la somme des cinq dés.",
            ScoreHelpKey.chance.rawValue: "Aucune combinaison imposée : additionnez les cinq dés.",
            ScoreHelpKey.full.rawValue: "Trois dés identiques et deux autres dés identiques. Le Full rapporte 25 points.",
            ScoreHelpKey.suite.rawValue: "Cinq valeurs consécutives : 1–2–3–4–5 ou 2–3–4–5–6. La grande suite rapporte 40 points.",
            ScoreHelpKey.petiteSuite.rawValue: "Quatre valeurs consécutives. La petite suite rapporte 30 points.",
            ScoreHelpKey.carre.rawValue: "Au moins quatre dés identiques. Le score correspond à la somme des cinq dés.",
            ScoreHelpKey.yams.rawValue: "Cinq dés identiques. Le Yahtzee rapporte 50 points.",
            ScoreHelpKey.extraYams.rawValue: "Après le premier Yahtzee, chaque Yahtzee supplémentaire peut rapporter une prime de 100 points."
        ]
    }
}
