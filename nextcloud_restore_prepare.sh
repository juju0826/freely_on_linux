#!/usr/bin/env bash
# Generic Restore Prepare Script
set -Eeuo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 BACKUP_DIR"; exit 1
fi

BACKUP="$1"

for dir in db data config; do
  [[ -d "$BACKUP/$dir" ]] || { echo "Missing $dir"; exit 1; }
done

command -v php >/dev/null || exit 1
command -v rsync >/dev/null || exit 1
command -v mysql >/dev/null || exit 1

echo "[OK] Backup structure valid"
echo "[OK] System dependencies OK"
