#!/usr/bin/env bash
# Generic Nextcloud Restore Script
set -Eeuo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 BACKUP_DIR"; exit 1
fi

BACKUP="$1"
NC_ROOT="/var/www/nextcloud"
NC_DATA="/var/www/nextcloud-data"

log(){ echo "[INFO] $*"; }

log "Stop services"
systemctl stop nginx || true
systemctl stop php*-fpm || true

log "Enable maintenance"
sudo -u www-data php "$NC_ROOT/occ" maintenance:mode --on || true

mv "$NC_DATA" "$NC_DATA.bak.$(date +%s)" || true
mv "$NC_ROOT/config" "$NC_ROOT/config.bak.$(date +%s)" || true

mkdir -p "$NC_DATA" "$NC_ROOT/config"

log "Restore data"
rsync -a "$BACKUP/data/" "$NC_DATA/"

log "Restore config"
rsync -a "$BACKUP/config/" "$NC_ROOT/config/"

log "Restore DB"
DB_NAME=$(php -r "include '$NC_ROOT/config/config.php'; echo \$CONFIG['dbname'];")
gunzip -c "$BACKUP/db/db.sql.gz" | mysql "$DB_NAME"

chown -R www-data:www-data "$NC_DATA" "$NC_ROOT/config"

log "Start services"
systemctl start php*-fpm || true
systemctl start nginx || true

sudo -u www-data php "$NC_ROOT/occ" maintenance:mode --off

echo "[OK] Restore complete"
