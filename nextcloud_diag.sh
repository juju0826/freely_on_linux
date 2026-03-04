#!/bin/bash

NC="/var/www/nextcloud"

echo "Nextcloud diagnostics"

sudo -u www-data php $NC/occ status

sudo -u www-data php $NC/occ background-job:list | head

systemctl status redis-server --no-pager | head

systemctl status php8.2-fpm --no-pager | head

lscpu | grep "Model name"

free -h

lsblk -o NAME,ROTA,SIZE,TYPE,MOUNTPOINT

sudo -u www-data dd if=/dev/zero of=/var/www/nextcloud-data/.iotest bs=1M count=512 conv=fdatasync 2>&1 | tail -n 1
rm -f /var/www/nextcloud-data/.iotest
