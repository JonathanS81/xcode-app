//
//  GDV.Helpers.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 14/09/2025.
//

import Foundation

enum GDV_Helpers {
    static func dashOr(_ value: Int) -> String { value >= 0 ? String(value) : "—" }
    // On déplacera ici ultérieurement les helpers purs (formatage, validations, etc.)
    static func displaySuiteValue(_ v: Int) -> String {
        switch v {
        case -1: return UIStrings.Common.dash
        case 0:  return UIStrings.Game.barred0
        case 15: return UIStrings.Game.suite15
        case 20: return UIStrings.Game.suite20
        default: return String(v)
        }
    }

    static func displayPetiteSuiteValue(_ v: Int) -> String {
        switch v {
        case -1: return UIStrings.Common.dash
        case 0:  return UIStrings.Game.barred0
        case 1:  return UIStrings.Game.petiteLbl
        default: return String(v)
        }
    }
    
}
