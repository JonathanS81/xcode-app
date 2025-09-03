import Foundation
import SwiftData

struct SampleData {
    static func ensureSamples(_ context: ModelContext) {
        let playersCount = (try? context.fetch(FetchDescriptor<Player>()))?.count ?? 0
        //if playersCount == 0 {
            //context.insert(Player(name: "Alice Dupont", nickname: "Ali"))
            //context.insert(Player(name: "Bruno Martin", nickname: "Bru"))
            //context.insert(Player(name: "Chloé Petit", nickname: "Clo"))
            //try? context.save()
        //}
        
        let notationsCount = (try? context.fetch(FetchDescriptor<Notation>()))?.count ?? 0
        /*if notationsCount == 0 {
            let classic = Notation(
                name: "Classique",
                tooltipUpper: "Atteindre 63 points en haut donne un bonus.",
                tooltipMiddle: "Règle bonus: Max>Min et Max+Min ≥ seuil ⇒ +bonus.",
                tooltipBottom: "Full/Carré/Yams = somme + prime fixe.",
                upperBonusThreshold: 63,
                upperBonusValue: 35,
                middleMode: .bonusGate,
                middleBonusSumThreshold: 50,
                middleBonusValue: 30,
                ruleBrelan: FigureRule(mode: .raw),
                ruleChance: FigureRule(mode: .raw),
                ruleFull: FigureRule(mode: .rawPlusFixed, fixedValue: 30),
                ruleSuite: FigureRule(mode: .fixed, fixedValue: 15),
                rulePetiteSuite: FigureRule(mode: .fixed, fixedValue: 10),
                ruleCarre: FigureRule(mode: .rawPlusFixed, fixedValue: 40),
                ruleYams: FigureRule(mode: .rawPlusFixed, fixedValue: 50),
                extraYamsBonusEnabled: true,
                extraYamsBonusValue: 100
            )
            context.insert(classic)
            try? context.save()
        }*/

    }
}
