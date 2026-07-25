#!/bin/sh
# Usage:
#   ./make_yamsheet.sh [project_root] [output_file]
# Example:
#   ./make_yamsheet.sh . yamsheet.txt

set -eu

ROOT="${1:-$(pwd)}"
OUT="${2:-yamsheet.txt}"

# Nettoie/crée le fichier de sortie
: > "$OUT"

echo "▶︎ Scanning sources under: $ROOT"

# On liste les fichiers texte utiles, en excluant les répertoires bruyants
find "$ROOT" \
  -type f \
  \( -name "*.swift" -o -name "Package.swift" -o -name "*.plist" -o -name "*.entitlements" -o -name "*.md" \) \
  ! -path "*/DerivedData/*" \
  ! -path "*/Pods/*" \
  ! -path "*/.git/*" \
  ! -path "*/.build/*" \
  ! -path "*/.swiftpm/*" \
  ! -path "*/xcuserdata/*" \
  ! -path "*/node_modules/*" \
| LC_ALL=C sort \
| while IFS= read -r f; do
    # calcule un chemin relatif si possible
    case "$f" in
      "$ROOT"/*) rel="${f#"$ROOT"/}" ;;
      *) rel="$f" ;;
    esac

    {
      printf '\n\n================================================================================\n'
      printf 'FILE: %s\n' "$rel"
      printf '================================================================================\n\n'
      cat "$f"
      printf '\n'
    } >> "$OUT"
  done

echo "✅ Done. Wrote $(wc -l < "$OUT") lines into: $OUT"
