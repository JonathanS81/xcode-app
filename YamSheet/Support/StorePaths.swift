//
//  StorePaths.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 12/10/2025.
//

// Support/StorePaths.swift
import Foundation

enum StorePaths {
    // ← Si tu veux l’App Group, mets le même ID dans Signing & Capabilities des deux branches
    static let appGroupID = "group.jsdevperso.yamsheet"   // ← adapte si besoin
    static let fileName   = "YamSheet.sqlite"             // ← même nom partout

    /// URL finale utilisée par SwiftData.
    static func storeURL() -> URL {
        let fm = FileManager.default

        // 1) Essayer App Group (si activé dans la cible)
        if let groupURL = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return groupURL.appendingPathComponent(fileName)
        }

        // 2) Fallback: Documents de l’app
        return fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    /// Si tu passes de Documents → App Group, copie une fois l’ancien fichier.
    static func migrateIfNeeded() {
        let fm = FileManager.default

        // Ancien emplacement (Documents)
        let oldURL = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)

        // Nouveau (App Group si dispo, sinon… c’est le même)
        guard let groupURL = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return // pas d’App Group configuré → rien à faire
        }
        let newURL = groupURL.appendingPathComponent(fileName)

        // Si le nouveau n’existe pas mais l’ancien oui → copier
        if !fm.fileExists(atPath: newURL.path), fm.fileExists(atPath: oldURL.path) {
            do {
                try fm.createDirectory(at: groupURL, withIntermediateDirectories: true)
                try fm.copyItem(at: oldURL, to: newURL)
                // Optionnel: garde une trace
                #if DEBUG
                print("StorePaths: migrated DB from Documents → App Group")
                #endif
            } catch {
                #if DEBUG
                print("StorePaths migration error:", error)
                #endif
            }
        }
    }

    /// Petit helper pour déboguer où pointe réellement le store.
    static func logStoreLocation() {
        #if DEBUG
        print("SwiftData store:", storeURL().path)
        #endif
    }
}
