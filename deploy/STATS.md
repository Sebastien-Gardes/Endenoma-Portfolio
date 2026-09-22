# Mesure d'audience d'endenoma.studio — sans cookie

## Ce que c'est

Le site ne charge **aucun script de mesure** et ne dépose **aucun cookie**.
La fréquentation est déduite des requêtes que nginx sert déjà, avec l'adresse
IP tronquée **avant** écriture sur le disque.

Conséquences :

- pas de bandeau de consentement à afficher ;
- aucune donnée transmise à un tiers, aucun compte à ouvrir, rien à payer ;
- le visiteur n'est pas suivi, y compris s'il bloque les traceurs ;
- rien à charger en plus, donc aucun impact sur la vitesse du site.

Ce que ça mesure : visites, pages vues, pages les plus consultées, sites et
URL de provenance, navigateur, système, mobile ou ordinateur, répartition
dans la journée, erreurs 404.

Ce que ça ne mesure pas : le temps passé sur une page, le défilement, les
clics. Ces mesures-là exigent un script côté navigateur ; elles ne sont pas
nécessaires pour savoir si un portfolio est consulté et par quel canal.

## Installation sur le VPS

Tout se fait en une fois, connecté en root. Les fichiers sont récupérés
depuis le dépôt pour éviter les copier-coller tronqués dans le terminal.

### 1. Les paquets

```bash
apt update && apt install -y goaccess apache2-utils
```

`apache2-utils` fournit `htpasswd`, pour le mot de passe du rapport.

### 2. Les fichiers de configuration

```bash
BASE=https://raw.githubusercontent.com/Sebastien-Gardes/Endenoma-Portfolio/main/deploy

curl -fsSL "$BASE/nginx-audience.conf"          -o /etc/nginx/conf.d/endenoma-audience.conf
curl -fsSL "$BASE/nginx-endenoma.studio.conf"   -o /etc/nginx/sites-available/endenoma.studio
curl -fsSL "$BASE/logrotate-endenoma-audience"  -o /etc/logrotate.d/endenoma-audience
curl -fsSL "$BASE/stats.sh"                     -o /usr/local/bin/endenoma-stats
chmod +x /usr/local/bin/endenoma-stats
```

### 3. Les dossiers

```bash
mkdir -p /var/log/endenoma /var/www/endenoma-stats
touch /var/log/endenoma/audience.log
chown www-data:adm /var/log/endenoma/audience.log
chmod 640 /var/log/endenoma/audience.log
```

### 4. Le mot de passe du rapport

Remplacer `seb` par l'identifiant voulu ; le mot de passe est demandé
ensuite, il ne s'affiche pas.

```bash
htpasswd -c /etc/nginx/.htpasswd-stats seb
chown root:www-data /etc/nginx/.htpasswd-stats
chmod 640 /etc/nginx/.htpasswd-stats
```

### 5. Vérifier puis recharger nginx

```bash
nginx -t && systemctl reload nginx
```

`nginx -t` doit répondre `syntax is ok` **et** `test is successful`. En cas
d'erreur, ne pas recharger : le site continue de tourner sur l'ancienne
configuration tant qu'on ne recharge pas.

### 6. Premier rapport

```bash
/usr/local/bin/endenoma-stats
```

Puis ouvrir **https://endenoma.studio/stats/** et saisir l'identifiant et le
mot de passe de l'étape 4.

Le journal étant vide au départ, le premier rapport le sera aussi. Charger
quelques pages du site, relancer la commande, et les chiffres apparaissent.

### 7. Mise à jour automatique

```bash
( crontab -l 2>/dev/null | grep -v endenoma-stats
  echo "7 * * * * /usr/local/bin/endenoma-stats >> /var/log/endenoma/stats.log 2>&1" ) | crontab -
crontab -l
```

Le rapport se régénère chaque heure, à 7 minutes passées. Le `grep -v` évite
d'empiler des lignes en double si la commande est relancée.

## Vérifier que l'anonymisation fonctionne

```bash
tail -3 /var/log/endenoma/audience.log
```

Chaque ligne doit commencer par une adresse se terminant par `.0` (IPv4) ou
par `::` (IPv6). Si une adresse complète apparaît, la `map` de
`conf.d/endenoma-audience.conf` n'est pas chargée : vérifier que
`/etc/nginx/nginx.conf` contient bien `include /etc/nginx/conf.d/*.conf;`
**avant** `include /etc/nginx/sites-enabled/*;`.

## Comment ça tient ensemble

| Fichier | Rôle |
|---|---|
| `nginx-audience.conf` | Tronque l'IP et définit le format du journal. À charger au niveau `http`, donc dans `conf.d/`. |
| `nginx-endenoma.studio.conf` | Écrit le journal d'audience et sert `/stats/` derrière un mot de passe. |
| `stats.sh` | Reconstruit le rapport HTML à partir du journal et de ses archives. |
| `logrotate-endenoma-audience` | Rotation mensuelle, 13 mois d'historique. |

Deux journaux coexistent, volontairement :

- `/var/log/nginx/endenoma.access.log` — IP **complète**, pour la sécurité et
  le diagnostic, purgé au bout de 14 jours par la rotation Ubuntu par défaut ;
- `/var/log/endenoma/audience.log` — IP **tronquée**, pour la mesure
  d'audience, conservé 13 mois.

Le second est délibérément hors de `/var/log/nginx` : la règle de rotation
livrée par Ubuntu y applique `rotate 14`, ce qui effacerait tout historique
d'audience, et deux règles visant le même fichier feraient échouer logrotate.

`/stats/` n'est pas comptabilisé dans l'audience (`access_log off`) et porte
un en-tête `X-Robots-Tag: noindex, nofollow`.

## Ce que dit la CNIL

La mesure d'audience est dispensée de consentement lorsqu'elle est
strictement limitée à la production de statistiques anonymes, réservée à
l'éditeur du site, sans recoupement avec d'autres traitements ni transmission
à des tiers. La troncature du dernier octet de l'adresse IP fait partie des
garanties attendues.

Ce dispositif remplit ces conditions : le traitement a lieu sur le serveur de
l'éditeur, aucune donnée ne sort, aucun identifiant n'est déposé sur le
terminal du visiteur, et aucune adresse IP complète n'est jamais écrite dans
le journal d'audience.

Contrepartie honnête : deux visiteurs partageant le même réseau `/24` sont
comptés comme un seul. Sur du trafic mobile, où les opérateurs regroupent
beaucoup d'abonnés derrière peu d'adresses, le nombre de visiteurs uniques est
donc **sous-estimé**. Le nombre de pages vues, lui, reste exact.

## Dépannage

**`/stats/` renvoie 404** — Le rapport n'a jamais été généré. Lancer
`/usr/local/bin/endenoma-stats` et lire ce qu'il affiche.

**`/stats/` renvoie 403** — Droits sur `/var/www/endenoma-stats`.
`chmod 755 /var/www/endenoma-stats` et `chmod 644` sur `index.html`.

**`goaccess absent`** — `apt install -y goaccess`.

**Le rapport reste vide alors que le site reçoit des visites** — Vérifier que
le journal se remplit : `wc -l /var/log/endenoma/audience.log`. S'il est vide,
nginx n'a pas été rechargé après l'étape 2.

**Les chiffres semblent bas** — Normal : `--ignore-crawlers` exclut les robots
d'indexation, qui représentent souvent la majorité des requêtes d'un petit
site. Ce qui reste correspond aux visiteurs réels.
