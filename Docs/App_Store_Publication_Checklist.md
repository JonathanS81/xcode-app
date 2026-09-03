# Checklist de publication App Store — YamSheet

> Document de référence pour préparer, tester et soumettre la première version publique de YamSheet.
>
> Dernière mise à jour : 29 juillet 2026
> Version préparée : 1.0  
> Build actuel : 1  
> État actuel : conformité technique en cours

## Légende

- `[x]` : terminé et vérifié
- `[ ]` : à faire ou à vérifier

## Prochaine action

- [ ] Finaliser les textes de la fiche App Store, puis préparer les captures d’écran iPhone.

---

## 1. Socle technique déjà validé

- [x] Icône App Store 1024 × 1024 préparée.
- [x] Déclinaisons de l’icône iPhone et iPad intégrées dans `AppIcon`.
- [x] Version minimale réglée sur iOS 17.
- [x] Projet compilé avec Xcode 26 et le SDK iOS 26.
- [x] Compilation validée sur simulateur iOS 17.
- [x] Compilation validée sur simulateur iOS 26.5.
- [x] Version marketing réglée sur `1.0`.
- [x] Numéro de build réglé sur `1`.
- [x] Signature automatique configurée avec l’équipe Apple.
- [x] Bundle ID du projet réglé sur `jsdevperso.YamSheet`.
- [x] Manifeste `PrivacyInfo.xcprivacy` ajouté au target principal.
- [x] Manifeste intégré et retrouvé dans le bundle compilé.
- [x] Absence de suivi déclarée dans le manifeste.
- [x] Absence de données collectées déclarée dans le manifeste.
- [x] Utilisation de `UserDefaults` déclarée avec la raison Apple `CA92.1`.
- [x] Présence du manifeste de confidentialité de Lottie vérifiée.

---

## 2. Conformité technique restante

### Confidentialité et chiffrement

- [x] Ajouter `ITSAppUsesNonExemptEncryption = NO` dans les informations du target.
- [x] Générer le rapport de confidentialité depuis une archive Xcode.
- [x] Vérifier que le rapport ne contient aucun domaine de suivi.
- [x] Vérifier que le rapport ne signale aucune API sans raison déclarée.
- [x] Vérifier les manifestes de toutes les dépendances dans l’archive finale.
- [x] Confirmer dans App Store Connect : « Nous ne collectons aucune donnée ».

### Signature et capacités

- [x] Vérifier que l’App ID `jsdevperso.YamSheet` existe dans le portail Apple Developer.
- [x] Vérifier que l’App Group `group.jsdevperso.yamsheet` est enregistré.
- [x] Vérifier que l’App Group est associé à l’App ID YamSheet.
- [x] Vérifier que le profil de distribution contient bien cette capacité.
- [ ] Confirmer que la conservation de l’App Group est réellement nécessaire (audit : actuellement inutilisé).

### Build de distribution

- [ ] Vérifier la configuration `Release`.
- [ ] Vérifier qu’aucun outil ou écran de debug n’est accessible en production.
- [ ] Vérifier qu’aucune donnée de démonstration n’est créée automatiquement.
- [ ] Vérifier l’absence d’erreur et d’avertissement bloquant dans l’archive.
- [ ] Vérifier la taille finale de l’application.
- [ ] Vérifier les licences et mentions requises par Lottie et ChartView.

---

## 3. Décision iPhone et iPad

Le projet cible actuellement les familles iPhone et iPad.

- [x] Décider que la version 1.0 sera publiée sur iPhone uniquement.

### Si iPhone et iPad sont conservés

- [ ] Tester l’application sur un simulateur iPad récent.
- [ ] Tester la création et la saisie d’une partie sur iPad.
- [ ] Tester les écrans Parties, Joueurs, Notations, Statistiques et Paramètres.
- [ ] Tester les différentes orientations autorisées.
- [ ] Vérifier les présentations de feuilles, menus et fenêtres modales.
- [ ] Préparer les captures App Store iPad.

### Si la version devient iPhone uniquement

- [x] Retirer iPad de `Targeted Device Family`.
- [x] Recompiler et revalider l’archive.
- [ ] Vérifier que l’application n’exige plus de captures iPad.

---

## 4. Recette fonctionnelle finale

### Installation et données

- [ ] Tester une installation entièrement propre.
- [ ] Vérifier le premier lancement sans crash.
- [ ] Vérifier la création des réglages et données initiales.
- [x] Tester une mise à jour depuis une version précédente.
- [x] Vérifier que les anciennes parties restent lisibles.
- [ ] Vérifier que les anciens scores et statistiques sont inchangés.
- [ ] Tester une sauvegarde complète `.yamsheet`.
- [ ] Tester la restauration de cette sauvegarde sur une installation propre.
- [ ] Vérifier que les doublons importés suivent la règle prévue.

### Joueurs et notations

- [ ] Créer, modifier et supprimer un joueur.
- [ ] Tester un nom de joueur long.
- [ ] Ajouter et modifier une photo de joueur.
- [ ] Vérifier les couleurs des joueurs dans les parties et les PDF.
- [ ] Créer et modifier une notation.
- [ ] Tester la petite suite activée et désactivée.
- [ ] Tester la chance activée et désactivée.
- [ ] Tester la prime Yams désactivée, unique et multiple.
- [ ] Tester les tooltips activés et désactivés.

### Parties

- [ ] Créer une partie avec un joueur.
- [ ] Créer une partie avec plusieurs joueurs.
- [ ] Vérifier l’ordre des joueurs.
- [ ] Saisir un score dans chaque section.
- [ ] Vérifier que « Joueur suivant » apparaît au bon moment.
- [ ] Vérifier que seule la bonne colonne devient active.
- [ ] Vérifier que la feuille ne change pas de position après validation.
- [ ] Vérifier que le bouton « Ce lancer est un Yams » ne décale pas la feuille.
- [ ] Tester un Yams déclaré dans une autre case.
- [ ] Tester une prime Yams unique.
- [x] Tester plusieurs primes Yams dans une même partie.
- [ ] Mettre une partie en pause et la reprendre.
- [ ] Fermer l’application pendant une partie puis la reprendre.
- [ ] Terminer normalement une partie.
- [ ] Vérifier l’écran de félicitations.
- [ ] Vérifier les scores finaux et le classement.
- [ ] Rechercher une partie par nom.
- [ ] Rechercher une partie par joueur.
- [ ] Vérifier les archives mensuelles avec un historique important.

### Statistiques

- [ ] Vérifier les statistiques individuelles.
- [ ] Vérifier les statistiques globales.
- [ ] Vérifier les filtres par notation.
- [ ] Vérifier les meilleurs et pires scores.
- [ ] Vérifier les victoires, moyennes et taux de victoire.
- [ ] Vérifier les podiums de Yams.
- [ ] Vérifier les podiums de primes Yams.
- [ ] Vérifier que les notations différentes ne sont pas comparées lorsque le filtre est actif.

### Export et import

- [ ] Exporter un joueur en PDF.
- [ ] Exporter plusieurs joueurs.
- [ ] Vérifier les graphiques et historiques des PDF joueurs.
- [ ] Exporter une partie en PDF.
- [ ] Vérifier que le récapitulatif tient sur une page.
- [ ] Vérifier le tableau des scores et les couleurs.
- [ ] Exporter des joueurs, parties et notations en `.yamsheet`.
- [ ] Importer chaque type de fichier `.yamsheet`.
- [ ] Tester une sauvegarde complète.
- [ ] Vérifier la sélection des fichiers dans le sélecteur iOS.

### Interface et accessibilité

- [ ] Tester le mode clair.
- [ ] Tester le mode sombre.
- [ ] Tester une taille de texte plus grande.
- [ ] Vérifier les contrastes et les boutons importants.
- [ ] Vérifier les libellés VoiceOver essentiels.
- [ ] Tester l’application en français sur tous les écrans.
- [ ] Vérifier l’absence de texte coupé sur les petits iPhone.

### Appareils

- [ ] Tester sur un véritable iPhone sous iOS 17 ou version proche.
- [x] Tester sur un véritable iPhone sous iOS 26 si disponible.
- [ ] Tester sur un véritable iPad si la compatibilité iPad est conservée.
- [ ] Tester sans connexion Internet.
- [ ] Tester avec peu d’espace disponible si possible.

---

## 5. Pages et informations légales

- [x] Créer une page publique de politique de confidentialité.
- [x] Indiquer que les données restent localement sur l’appareil.
- [x] Expliquer les exports déclenchés volontairement par l’utilisateur.
- [x] Ajouter l’adresse de contact `yamsheet.contact@gmail.com`.
- [x] Publier la politique sur une URL stable en HTTPS.
- [x] Créer une page publique d’assistance.
- [x] Ajouter un moyen de contact visible sur la page d’assistance.
- [x] Décider du statut DSA : non-professionnel.
- [x] Compléter et valider le statut DSA dans App Store Connect.
- [x] Répondre au questionnaire de classification d’âge 2026.
- [x] Déclarer l’absence de paris, d’argent réel et de jeu d’argent.
- [x] Vérifier les droits sur les icônes, images, animations et autres ressources.
- [x] Choisir le nom à utiliser pour le copyright : `2026 Jonathan Sportiche`.
- [ ] Vérifier les contrats Apple Developer dans App Store Connect.

---

## 6. Création de l’application dans App Store Connect

- [x] Vérifier que le nom `YamSheet` est disponible.
- [x] Créer la fiche de l’application.
- [x] Choisir le français comme langue principale.
- [x] Sélectionner le Bundle ID `jsdevperso.YamSheet`.
- [x] Définir un SKU interne, par exemple `YAMSHEET-IOS-001`.
- [x] Choisir la catégorie principale : Utilitaires.
- [x] Choisir la catégorie secondaire : Jeux — Board et Family.
- [x] Définir l’application comme gratuite.
- [x] Choisir tous les pays et régions de disponibilité.
- [x] Compléter les informations sur les droits de contenu.
- [x] Compléter la classification d’âge.
- [x] Compléter la section App Privacy.
- [x] Ajouter l’URL de politique de confidentialité.
- [ ] Compléter les informations d’accessibilité si les critères sont vérifiés.

---

## 7. Fiche App Store

### Textes

- [x] Valider le nom public : `YamSheet`.
- [x] Rédiger le sous-titre : `Scores et statistiques de Yams` (29 caractères).
- [x] Rédiger et valider la description App Store.
- [x] Préparer les mots-clés App Store (94 octets sur 100).
- [ ] Rédiger éventuellement le texte promotionnel, 170 caractères maximum.
- [x] Ajouter l’URL d’assistance.
- [x] Ajouter l’URL de politique de confidentialité.
- [ ] Ajouter éventuellement une URL marketing.
- [x] Ajouter le copyright : `2026 Jonathan Sportiche`.

### Captures

- [ ] Définir les écrans à montrer.
- [ ] Préparer des données de démonstration propres.
- [ ] Capturer l’écran Parties.
- [ ] Capturer une feuille de score.
- [ ] Capturer la gestion des joueurs.
- [ ] Capturer les notations.
- [ ] Capturer les statistiques.
- [ ] Capturer l’export ou les paramètres si pertinent.
- [ ] Produire les captures iPhone aux dimensions requises.
- [ ] Produire les captures iPad si l’iPad est conservé.
- [ ] Vérifier qu’aucune donnée personnelle réelle n’apparaît.
- [ ] Vérifier l’ordre des captures dans App Store Connect.
- [ ] Décider si une vidéo App Preview est utile ; elle reste facultative.

---

## 8. Archive et TestFlight

- [x] Sélectionner `Any iOS Device (arm64)` dans Xcode.
- [x] Lancer `Product > Archive`.
- [x] Ouvrir l’archive dans Organizer.
- [x] Générer et examiner le rapport de confidentialité.
- [x] Lancer `Validate App`.
- [x] Corriger toutes les erreurs de validation — aucune erreur signalée.
- [x] Examiner chaque avertissement — aucun avertissement signalé.
- [x] Choisir `Distribute App > App Store Connect > Upload`.
- [x] Attendre la fin du traitement du build.
- [x] Vérifier les éventuels messages d’Apple — aucun blocage signalé.
- [x] Répondre aux questions de conformité du chiffrement — aucune action supplémentaire demandée grâce à `ITSAppUsesNonExemptEncryption = NO`.
- [x] Vérifier que le build apparaît dans TestFlight avec le statut `Ready to Submit`.
- [x] Ajouter les testeurs internes.
- [x] Installer YamSheet depuis TestFlight.
- [x] Effectuer une recette rapide depuis le build TestFlight.
- [x] Vérifier la conservation des données après une mise à jour TestFlight.
- [ ] Ajouter éventuellement des testeurs externes.
- [ ] Soumettre le build à la Beta App Review si des testeurs externes sont utilisés.
- [ ] Incrémenter le numéro de build avant chaque nouvel envoi.

---

## 9. Soumission à App Review

- [x] Créer ou ouvrir la version iOS 1.0.
- [ ] Sélectionner le build TestFlight validé.
- [ ] Vérifier toutes les métadonnées obligatoires.
- [ ] Ajouter le nom du contact App Review.
- [ ] Ajouter l’adresse email du contact.
- [ ] Ajouter le numéro de téléphone du contact.
- [ ] Indiquer qu’aucun compte n’est nécessaire.
- [ ] Rédiger les notes destinées à l’équipe de validation.
- [ ] Expliquer rapidement comment créer et jouer une partie.
- [ ] Signaler que les données sont stockées localement.
- [ ] Choisir une publication manuelle après approbation.
- [ ] Cliquer sur `Add for Review`.
- [ ] Vérifier le brouillon de soumission.
- [ ] Cliquer sur `Submit for Review`.
- [ ] Surveiller les messages de l’équipe App Review.
- [ ] Répondre rapidement à toute demande d’information.

---

## 10. Après approbation

- [ ] Relire une dernière fois la fiche publique.
- [ ] Déclencher manuellement la publication.
- [ ] Vérifier l’apparition de YamSheet sur l’App Store.
- [ ] Installer la version publique depuis l’App Store.
- [ ] Vérifier le premier lancement de la version publique.
- [ ] Vérifier le téléchargement, l’export et l’import.
- [ ] Surveiller les crashs et retours utilisateurs.
- [ ] Conserver une copie du build, de l’archive et des métadonnées 1.0.
- [ ] Créer une nouvelle branche pour les changements de la version suivante.
- [ ] Passer la version suivante à `1.0.1` ou `1.1` selon son contenu.

---

## Décisions à conserver

| Sujet | Décision actuelle |
|---|---|
| Version minimale | iOS 17 |
| Version App Store | 1.0 |
| Build actuel | 1 |
| Bundle ID | `jsdevperso.YamSheet` |
| Collecte de données | Aucune |
| Suivi publicitaire | Aucun |
| API avec raison déclarée | `UserDefaults` — `CA92.1` |
| Langue principale envisagée | Français |
| Mode de publication envisagé | Publication manuelle après approbation |
| iPad | Non pour la version 1.0 — iPhone uniquement |
| Prix | Gratuit |
| Disponibilité | Tous les pays et régions |
| Copyright | `2026 Jonathan Sportiche` |
| Statut DSA | Non-professionnel (`non-trader`) |
| Catégorie App Store | Utilitaires (principale) / Jeux — Board et Family (secondaire) |

---

## Journal de progression

### 27 juillet 2026

- Icône App Store finalisée.
- Version minimale iOS 17 validée.
- Compilation Xcode 26 validée sur iOS 17 et iOS 26.5.
- Manifeste `PrivacyInfo.xcprivacy` ajouté et intégré.
- Absence de collecte et de suivi déclarée.
- Raison Apple `CA92.1` ajoutée pour `UserDefaults`.
- Déclaration de chiffrement exempté ajoutée aux configurations Debug et Release, puis vérifiée dans une archive Release.
- Rapport de confidentialité Xcode généré depuis l’archive du 27 juillet 2026 à 22:45.
- Rapport contrôlé : aucune collecte et aucun domaine de suivi affichés.
- Archive contrôlée : manifeste YamSheet valide (`UserDefaults` — `CA92.1`) et manifeste Lottie valide (dates de fichiers — `C617.1`).
- ChartView 1.5.5 contrôlé : aucune API nécessitant une raison déclarée et aucun mécanisme de suivi détectés.
- Prime Yams multiple corrigée et validée : une nouvelle prime peut être attribuée après chaque Yams suivant le premier.
- Fiche YamSheet créée dans App Store Connect et absence de collecte confirmée.
- App ID et App Group vérifiés dans les droits signés de l’archive.
- Audit du stockage : la base active reste dans le dossier Documents ; le helper App Group n’est actuellement jamais appelé.
- Pages de confidentialité et d’assistance préparées avec l’adresse `yamsheet.contact@gmail.com`.
- Déploiement automatique GitHub Pages préparé pour le dépôt `JonathanS81/yamsheet`.
- Build Release installé sur un iPhone 16 Pro sous iOS 26.5.2 par-dessus la version de test existante ; historique et anciennes parties conservés.

### 28 juillet 2026

- Branche de préparation App Store fusionnée dans `main`.
- Pages publiques YamSheet déployées par GitHub Pages.
- URL principale vérifiée en HTTPS : `https://jonathans81.github.io/yamsheet/`.
- Politique de confidentialité vérifiée en HTTPS : `https://jonathans81.github.io/yamsheet/privacy/`.
- Page d’assistance vérifiée en HTTPS : `https://jonathans81.github.io/yamsheet/support/`.
- Ancien domaine `bitcoinference.fr` détaché du site GitHub Pages du compte.
- URL de politique de confidentialité ajoutée dans App Store Connect.
- URL d’assistance ajoutée à la fiche française de la version 1.0.
- Statut DSA déclaré dans App Store Connect : compte non-professionnel (`non-trader`).
- Catégories App Store enregistrées : Utilitaires en catégorie principale et Jeux — Board et Family en catégorie secondaire.
- Prix App Store configuré sur Gratuit.
- Disponibilité App Store configurée pour tous les pays et régions.
- Provenance et licences des dépendances et animations enregistrées dans `Docs/Third_Party_Content_and_Licenses.md`.
- Droits de contenu déclarés dans App Store Connect : contenu tiers utilisé avec les droits nécessaires.
- Copyright de la version 1.0 enregistré : `2026 Jonathan Sportiche`.
- Questionnaire de classification d’âge 2026 complété, sans jeu d’argent réel ou simulé.
- Version 1.0 limitée à l’iPhone ; iPad retiré de `Targeted Device Family` pour les configurations Debug et Release de la cible principale.
- Compilation Release validée sur un simulateur iPhone 15 Pro sous iOS 17 après le passage en iPhone uniquement.
- Nouvelle archive YamSheet 1.0 (build 1) créée et validée avec succès par Xcode, sans erreur ni avertissement.
- Archive YamSheet 1.0 (build 1) envoyée avec succès à App Store Connect depuis Xcode.
- Traitement Apple terminé ; build 1 visible dans TestFlight avec le statut `Ready to Submit`, sans blocage de conformité.

### 29 juillet 2026

- Groupe de test interne créé dans TestFlight.
- Compte interne ajouté au groupe et YamSheet 1.0 (build 1) installé depuis TestFlight.
- Recette TestFlight validée : données historiques conservées, ancienne partie consultable, nouvelle partie créée, saisie des scores et des Yams validée, changement de joueur et reprise fonctionnels, persistance après redémarrage confirmée, statistiques et export vérifiés.
- Nom public et sous-titre App Store validés : `YamSheet` — `Scores et statistiques de Yams`.
- Description App Store et mots-clés français validés.

---

## Références Apple

- [Exigences de soumission à venir](https://developer.apple.com/news/upcoming-requirements/)
- [Manifeste de confidentialité](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [API nécessitant une raison déclarée](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [Gestion de la confidentialité App Store](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [Informations d’une version App Store](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)
- [Envoi d’un build](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
- [Soumission à App Review](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app)
