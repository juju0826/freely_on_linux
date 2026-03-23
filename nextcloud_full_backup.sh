#!/usr/bin/env bash
# Generic Nextcloud Backup Script
set -Eeuo pipefail

NC_ROOT="/var/www/nextcloud"
NC_DATA="/var/www/nextcloud-data"
BACKUP_ROOT="/mnt/backup/nextcloud"
BACKUP_OWNER="${BACKUP_OWNER:-$(whoami)}"
RETENTION_COUNT=4

TIMESTAMP="$(date +%F_%H%M%S)"
TARGET="$BACKUP_ROOT/full-$TIMESTAMP"

log(){ echo "[INFO] $*"; }

mkdir -p "$BACKUP_ROOT"

if ! mountpoint -q /mnt/backup; then
  echo "[ERROR] backup mount not found"; exit 1
fi

log "Reading DB config"
DB_NAME=$(sudo php -r "include '$NC_ROOT/config/config.php'; echo \$CONFIG['dbname'];")
DB_USER=$(sudo php -r "include '$NC_ROOT/config/config.php'; echo \$CONFIG['dbuser'];")
DB_PASS=$(sudo php -r "include '$NC_ROOT/config/config.php'; echo \$CONFIG['dbpassword'];")

mkdir -p "$TARGET"/{db,data,config}

log "Enable maintenance"
sudo -u www-data php "$NC_ROOT/occ" maintenance:mode --on

log "Dump DB"
mysqldump -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" | gzip > "$TARGET/db/db.sql.gz"

log "Backup data"
sudo rsync -a "$NC_DATA/" "$TARGET/data/"

log "Backup config"
sudo rsync -a "$NC_ROOT/config/" "$TARGET/config/"

sudo chown -R "$BACKUP_OWNER":"$BACKUP_OWNER" "$TARGET"

log "Disable maintenance"
sudo -u www-data php "$NC_ROOT/occ" maintenance:mode --off

log "Retention"
ls -dt $BACKUP_ROOT/full-* | tail -n +$((RETENTION_COUNT+1)) | xargs -r rm -rf

echo "[OK] Backup done: $TARGET"
