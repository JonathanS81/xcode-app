#!/bin/sh
set -eu

# === CONFIG ===
ROOT="${1:-$(pwd)}"
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$ROOT/Backup_before_cleanup/$TS"
REMOVED_DIR="$BACKUP_DIR/removed"
MUTATED_DIR="$BACKUP_DIR/mutated"

# Canonical paths à garder (on supprime/archivera les autres doublons)
APP_STATS_CANON="YamSheet/Views/stats/AppStatsView.swift"
NEW_PLAYER_CANON="YamSheet/Views/players/NewPlayerView.swift"
DEBUGKIT_DIR="YamSheet/Support/DebugKit"
DEBUGCONFIG_CANON="$DEBUGKIT_DIR/DebugConfig.swift"
DEBUGLOG_CANON="$DEBUGKIT_DIR/DebugLog.swift"
DEBUGSETTINGS_CANON="$DEBUGKIT_DIR/DebugSettingsView.swift"

# Fichiers où remplacer les print(...) de debug par DLog(...)
PRINT_TO_DLOG="
YamSheet/Views/games/GameDetailView.swift
YamSheet/Views/games/EndGameCongratsView.swift
YamSheet/Support/LottieSupport.swift
YamSheet/Support/DevSeed.swift
"

# === PREP ===
echo "▶︎ Backup vers: $BACKUP_DIR"
mkdir -p "$REMOVED_DIR" "$MUTATED_DIR"

echo "▶︎ Sauvegarde complète du projet (rsync)…"
rsync -a --exclude 'DerivedData' --exclude '.git' --exclude 'Build' "$ROOT/" "$BACKUP_DIR/full_project/"

cd "$ROOT"

# --- helper pour archiver un fichier supprimé
archive_removed() {
  rel="$1"
  dst="$REMOVED_DIR/$rel"
  mkdir -p "$(dirname "$dst")"
  echo "  • archive: $rel"
  mv "$rel" "$dst"
}

# --- helper pour archiver et muter un fichier (copie avant modif)
archive_mutated() {
  rel="$1"
  dst="$MUTATED_DIR/$rel"
  mkdir -p "$(dirname "$dst")"
  cp "$rel" "$dst"
}

# === A) SUPPRESSION DES DOUBLONS ===
echo "▶︎ Recherche & archivage des doublons…"

# 1) AppStatsView.swift — garder la version canonique, archiver les autres
FOUND_APP_STATS=$(find YamSheet -name 'AppStatsView.swift' -type f | LC_ALL=C sort || true)
echo "$FOUND_APP_STATS" | while IFS= read -r f; do
  [ -z "$f" ] && continue
  if [ "$f" != "$APP_STATS_CANON" ]; then
    archive_removed "$f"
  fi
done

# 2) NewPlayerView.swift — garder la version canonique
FOUND_NEW_PLAYER=$(find YamSheet -name 'NewPlayerView.swift' -type f | LC_ALL=C sort || true)
echo "$FOUND_NEW_PLAYER" | while IFS= read -r f; do
  [ -z "$f" ] && continue
  if [ "$f" != "$NEW_PLAYER_CANON" ]; then
    archive_removed "$f"
  fi
done

# 3) DebugKit files — garder ceux sous Support/DebugKit
for base in DebugConfig.swift DebugLog.swift DebugSettingsView.swift; do
  FOUND=$(find YamSheet -name "$base" -type f | LC_ALL=C sort || true)
  echo "$FOUND" | while IFS= read -r f; do
    [ -z "$f" ] && continue
    case "$f" in
      "$DEBUGKIT_DIR"/*) : ;; # ok
      *) archive_removed "$f" ;;
    esac
  done
done

# 4) SampleData obsolète (si présent)
if [ -f "YamSheet/Persistence/SampleData.swift" ]; then
  archive_removed "YamSheet/Persistence/SampleData.swift"
fi

# === B) REMPLACER les print(...) de debug par DLog(...) ===
echo "▶︎ Remplacement des print(...) de debug par DLog(...)…"
echo "$PRINT_TO_DLOG" | while IFS= read -r rel; do
  [ -z "$rel" ] && continue
  if [ -f "$rel" ]; then
    archive_mutated "$rel"
    # Remplace print("…") par DLog("…") — simple et sûr
    # (On évite YamSheetApp.swift pour garder les prints prod utiles)
    perl -0777 -pe 's/\bprint\s*\(\s*("|\[)/DLog\($1/g' -i "$rel"
  fi
done

# === C) StatsService.swift — garder UNE SEULE appStats(...) ===
# On garde la 1ère définition de `static func appStats(` et on commente les suivantes.
STATS_FILE="YamSheet/Services/StatsService.swift"
if [ -f "$STATS_FILE" ]; then
  echo "▶︎ Déduplication appStats(...) dans $STATS_FILE"
  archive_mutated "$STATS_FILE"
  awk '
    BEGIN { keepCount=0; }
    # Détecte le début d une appStats
    /static[ \t]+func[ \t]+appStats[ \t]*\(/ {
      if (keepCount==0) {
        keepCount=1; print; next;
      } else {
        # commenter la version suivante jusqu à la fin du bloc (matching braces)
        comment=1; depth=0;
        print "// DEDUP REMOVED: " $0;
        next;
      }
    }
    comment==1 {
      # suivi bloc: compter { }
      for (i=1; i<=length($0); i++) {
        c=substr($0,i,1);
        if (c=="{") depth++;
        else if (c=="}") {
          if (depth>0) depth--;
          else {
            # fin du bloc courant
            print "// DEDUP REMOVED: " $0;
            comment=0;
            next;
          }
        }
      }
      print "// DEDUP REMOVED: " $0;
      next;
    }
    { print; }
  ' "$STATS_FILE" > "$STATS_FILE.tmp" && mv "$STATS_FILE.tmp" "$STATS_FILE"
fi

# === D) Résumé
echo "✅ Nettoyage terminé."
echo "   • Sauvegarde complète : $BACKUP_DIR/full_project/"
echo "   • Fichiers retirés (doublons) : $REMOVED_DIR"
echo "   • Fichiers modifiés (copie avant modif) : $MUTATED_DIR"
