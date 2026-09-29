#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  Fabrique l'aperçu animé et l'affiche d'une vidéo du site,
#  directement sur le VPS, à partir du gestionnaire de fichiers.
#
#  Usage : bash apercus.sh "Nom de la vidéo.mp4" identifiant seconde
#    ex.   bash apercus.sh "bestof festival 2026.mp4" grdf-aftermovie 20
#
#  Produit, à partir de la seconde indiquée :
#    Vidéos du site/<identifiant>-apercu.mp4      6 s, muet, léger
#    Images du site/<identifiant>-affiche.webp    image de couverture
#    Images du site/<identifiant>-affiche-<l>.webp  version réduite
#  L'orientation (paysage ou vertical) est détectée toute seule.
#  Relancer avec une autre seconde remplace les fichiers : le site
#  affiche la nouvelle version dès la visite suivante.
# ─────────────────────────────────────────────────────────────
set -euo pipefail

BASE="${BASE:-/var/www/filemanager}"
VIDEOS="$BASE/Vidéos du site"
IMAGES="$BASE/Images du site"

if [ $# -ne 3 ]; then
  echo "Usage : bash apercus.sh \"Nom de la vidéo.mp4\" identifiant seconde" >&2
  exit 1
fi
SOURCE="$VIDEOS/$1"; ID="$2"; T="$3"

[ -f "$SOURCE" ] || { echo "Introuvable : $SOURCE" >&2; exit 1; }
command -v ffmpeg >/dev/null || { echo "ffmpeg absent : apt install -y ffmpeg" >&2; exit 1; }

sonde() { ffprobe -v error -select_streams v:0 -show_entries "$1" -of default=nw=1:nk=1 "$SOURCE" | head -1; }
L=$(sonde stream=width); H=$(sonde stream=height)
case "$L$H" in ''|*[!0-9]*) echo "Dimensions illisibles : ${L}x${H}" >&2; exit 1;; esac
# Une vidéo tournée au téléphone peut être stockée en paysage avec une
# rotation : on tient compte de la rotation déclarée.
ROT=$(sonde stream_side_data=rotation | tr -d '-')
if [ "${ROT:-0}" = 90 ] || [ "${ROT:-0}" = 270 ]; then TMP=$L; L=$H; H=$TMP; fi

if [ "$H" -gt "$L" ]; then
  APERCU=360:640; AFFICHE=540:960; PETITE=270:480; FORME="vertical"
else
  APERCU=640:360; AFFICHE=1920:1080; PETITE=960:540; FORME="paysage"
fi
cadre() { echo "scale=$1:force_original_aspect_ratio=increase,crop=$1"; }

echo "$1 : $FORME ${L}×${H}, extrait à partir de ${T} s"

ffmpeg -v error -y -ss "$T" -i "$SOURCE" -t 6 -an \
  -vf "$(cadre $APERCU),fps=30" \
  -c:v libx264 -profile:v high -pix_fmt yuv420p -crf 28 -preset slow \
  -movflags +faststart "$VIDEOS/$ID-apercu.mp4"

ffmpeg -v error -y -ss "$T" -i "$SOURCE" -frames:v 1 \
  -vf "$(cadre $AFFICHE)" -c:v libwebp -quality 78 "$IMAGES/$ID-affiche.webp"

ffmpeg -v error -y -ss "$T" -i "$SOURCE" -frames:v 1 \
  -vf "$(cadre $PETITE)" -c:v libwebp -quality 78 "$IMAGES/$ID-affiche-${PETITE%%:*}.webp"

chown www-data:www-data "$VIDEOS/$ID-apercu.mp4" "$IMAGES/$ID-affiche.webp" \
  "$IMAGES/$ID-affiche-${PETITE%%:*}.webp" 2>/dev/null || true

ls -lh "$VIDEOS/$ID-apercu.mp4" "$IMAGES/$ID-affiche.webp" "$IMAGES/$ID-affiche-${PETITE%%:*}.webp"
