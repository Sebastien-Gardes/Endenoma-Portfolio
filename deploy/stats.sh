#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  endenoma.studio — génération du rapport d'audience.
#  → /usr/local/bin/endenoma-stats   (lancé par cron)
#
#  Lit le journal d'accès anonymisé et produit un rapport HTML
#  statique, servi sous /stats/ derrière un mot de passe.
#
#  Rien n'est envoyé à l'extérieur : ni cookie, ni script tiers,
#  ni compte chez un prestataire. Le rapport est reconstruit
#  intégralement à chaque passage, à partir du journal courant
#  et de ses archives, donc aucun double comptage possible.
# ─────────────────────────────────────────────────────────────
set -euo pipefail

JOURNAL="/var/log/endenoma/audience.log"
SORTIE="/var/www/endenoma-stats"
RAPPORT="$SORTIE/index.html"

command -v goaccess >/dev/null 2>&1 || {
    echo "$(date -Is) goaccess absent — installer avec : apt install goaccess" >&2
    exit 1
}

[ -f "$JOURNAL" ] || {
    echo "$(date -Is) journal introuvable : $JOURNAL" >&2
    exit 1
}

mkdir -p "$SORTIE"
TEMPO="$(mktemp)"
trap 'rm -f "$TEMPO" "$TEMPO.html"' EXIT

# Archives d'abord (endenoma-audience.log.1, .2.gz, …) puis le
# journal courant. « zcat -f » avale indifféremment le compressé
# et le texte brut.
{
    find "$(dirname "$JOURNAL")" -maxdepth 1 -name "$(basename "$JOURNAL").*" -print0 \
        | sort -zr \
        | xargs -0 -r zcat -f 2>/dev/null || true
    cat "$JOURNAL"
# --enable-panel=REFERRERS : le paquet Ubuntu de GoAccess livre un
# /etc/goaccess/goaccess.conf où « ignore-panel REFERRERS » est actif,
# ce qui masque les URL de provenance. On le réactive explicitement.
} | goaccess - \
        --no-global-config \
        --log-format=COMBINED \
        --ignore-crawlers \
        --enable-panel=REFERRERS \
        --real-os \
        --html-report-title="endenoma.studio — audience" \
        --no-progress \
        -o "$TEMPO.html"

mv "$TEMPO.html" "$RAPPORT"
chmod 644 "$RAPPORT"
echo "$(date -Is) rapport regénéré : $RAPPORT"
