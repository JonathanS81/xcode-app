# YamSheet — Spécification technique et fonctionnelle

## 1. Architecture générale
Application iOS développée en SwiftUI + SwiftData, utilisant une architecture MVVM simplifiée.

### Modules principaux
- GameDetailView : Vue principale d'une partie.
- NewGameView : Création d'une partie et sélection des joueurs.
- OrderSetupSheet : Ordre de jeu par glisser-déposer.
- Stats : Vue de statistiques globales et individuelles.
- Player : Modèle représentant un joueur.
- Scorecard : Modèle représentant la feuille de score d'un joueur.
- Game : Modèle principal gérant les tours et les options.

## 2. Persistance SwiftData
- Conteneur : `YamSheet.store` (SQLite)
- Modèles persistés : Game, Player, Scorecard
- Relations : Game -> Scorecards (cascade), Game -> Players (IDs)
- Migration : champs Array codés manuellement via Data (UUID, Bool, String)
- ColorData : stockage des couleurs joueurs (Codable RGBA).

## 3. Flux d’utilisation
1. Création d'une partie via NewGameView.
2. Sélection et ordre des joueurs via OrderSetupSheet.
3. Affichage de la grille de score dans GameDetailView.
4. Gestion des tours et progression automatique.
5. Fin de partie avec écran de résumé et statistiques.

## 4. Statistiques
- Vue globale : podiums, victoires, Yams, moyennes.
- Vue individuelle : taux de réussite, courbes d’évolution, histogrammes.

## 5. Migration & compatibilité
- Gestion rétrocompatible des anciens modèles.
- Sauvegarde automatique des snapshots notations.
- Optionnalisation progressive des propriétés anciennes.

## 6. Fichiers principaux
Voir arborescence complète dans `Docs/tree_template.txt`.
