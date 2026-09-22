#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  Déploiement d'endenoma.studio sur le VPS.
#  Récupère la branche main du dépôt et met à jour le webroot,
#  uniquement si le dépôt a changé depuis le dernier passage.
#
#  Installation :
#    curl -fsSL <url de ce fichier> -o /usr/local/bin/endenoma-deploy
#    chmod +x /usr/local/bin/endenoma-deploy
#
#  Usage : endenoma-deploy [--force]
# ─────────────────────────────────────────────────────────────
set -euo pipefail

REPO="Sebastien-Gardes/Endenoma-Portfolio"
BRANCHE="main"
WEBROOT="/var/www/endenoma.studio"
ETAT="/var/lib/endenoma-deploy.sha"
CONTENU=(index.html CGU.html logos-data.js robots.txt sitemap.xml uploads projets)

log() { echo "$(date -Is) $*"; }

# ── Verrou d'exclusion ──
# Deux passages simultanés — ligne cron dupliquée, ou lancement manuel
# pendant un passage automatique — copieraient dans le webroot en même
# temps, ce qui peut laisser un fichier tronqué le temps de la copie.
exec 9>/var/lock/endenoma-deploy.lock
if ! flock -n 9; then
  log "un deploiement est deja en cours, passage ignore"
  exit 0
fi

# ── Commit actuel de la branche ──
SHA=$(curl -fsSL --max-time 30 "https://api.github.com/repos/$REPO/commits/$BRANCHE" \
      | python3 -c 'import sys,json; print(json.load(sys.stdin)["sha"])')

if [ -z "$SHA" ]; then log "ABANDON : commit introuvable"; exit 1; fi

if [ "${1:-}" != "--force" ] && [ -f "$ETAT" ] && [ "$(cat "$ETAT")" = "$SHA" ]; then
  log "deja a jour (${SHA:0:7})"
  exit 0
fi

# ── Téléchargement dans un dossier temporaire ──
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

log "recuperation de ${SHA:0:7}"
curl -fsSL --max-time 180 \
  "https://codeload.github.com/$REPO/tar.gz/$SHA" \
  | tar xz -C "$TMP" --strip-components=1

# ── Garde-fou : on ne remplace rien si l'archive est incomplète ──
for f in "${CONTENU[@]}"; do
  if [ ! -e "$TMP/$f" ]; then log "ABANDON : $f absent de l archive, webroot inchange"; exit 1; fi
done
if [ ! -s "$TMP/index.html" ]; then log "ABANDON : index.html vide, webroot inchange"; exit 1; fi

# ── Mise en place ──
mkdir -p "$WEBROOT"
for f in "${CONTENU[@]}"; do
  cp -r "$TMP/$f" "$WEBROOT/"
done

chown -R www-data:www-data "$WEBROOT"
find "$WEBROOT" -type d -exec chmod 755 {} +
find "$WEBROOT" -type f -exec chmod 644 {} +

mkdir -p "$(dirname "$ETAT")"
echo "$SHA" > "$ETAT"

log "deploye ${SHA:0:7} ($(du -sh "$WEBROOT" | cut -f1))"
