#!/usr/bin/env bash

INTERVAL=2

RED="\e[31m"
YELLOW="\e[33m"
GREEN="\e[32m"
RESET="\e[0m"

dot_color() {

v=$1

if (( $(echo "$v < 50" | bc -l) )); then
echo -e "${GREEN}●${RESET}"
elif (( $(echo "$v < 75" | bc -l) )); then
echo -e "${YELLOW}●${RESET}"
else
echo -e "${RED}●${RESET}"
fi

}

num_color() {

v=$1

if (( $(echo "$v < 50" | bc -l) )); then
echo -e "${GREEN}${v}%${RESET}"
elif (( $(echo "$v < 75" | bc -l) )); then
echo -e "${YELLOW}${v}%${RESET}"
else
echo -e "${RED}${v}%${RESET}"
fi

}

draw_static() {

clear

echo "====================================="
echo "Collabora / Nextcloud Monitor"
echo "====================================="
echo
echo "CPU usage     : "
echo "Load average  : "
echo
echo "RAM usage     : "
echo
echo "Disk util     : "
echo
echo "Network RX    : "
echo
echo "Collabora CPU : "
echo "Collabora MEM : "
echo
echo "php-fpm workers : "
echo "Redis clients   : "
echo "Collabora sessions : "
echo
echo "Status : "

}

draw_static

while true
do

CPU=$(mpstat 1 1 | awk '/Average/ {print 100-$NF}')
CPU=$(printf "%.1f" $CPU)

LOAD=$(uptime | awk -F'load average:' '{print $2}')

RAM=$(free | awk '/Mem:/ {printf("%.0f"), $3/$2*100}')

DISK=$(iostat -dx 1 1 | awk '/sdb/ {print $NF}')
DISK=${DISK:-0}

NET=$(ifstat 1 1 | tail -1 | awk '{print $1}')
NET=${NET:-0}

COLLCPU=$(ps -C coolwsd -o %cpu= | awk '{s+=$1} END {print s+0}')
COLLMEM=$(ps -C coolwsd -o %mem= | awk '{s+=$1} END {print s+0}')

PHPWORK=$(ps -C php-fpm8.2 | wc -l)

REDIS=$(redis-cli info clients 2>/dev/null | grep connected_clients | cut -d: -f2)

WS=$(ss -tn | grep :9980 | wc -l)

tput cup 4 17
echo -ne "$(num_color $CPU)  $(dot_color $CPU)"

tput cup 5 17
echo -ne "$LOAD"

tput cup 7 17
echo -ne "$(num_color $RAM)  $(dot_color $RAM)"

tput cup 9 17
echo -ne "$(num_color $DISK)  $(dot_color $DISK)"

tput cup 11 17
echo -ne "$NET KB/s"

tput cup 13 17
echo -ne "$COLLCPU %"

tput cup 14 17
echo -ne "$COLLMEM %"

tput cup 16 19
echo -ne "$PHPWORK"

tput cup 17 19
echo -ne "$REDIS"

tput cup 18 22
echo -ne "$WS"

CPUINT=$(printf "%.0f" $CPU)

if [ "$CPUINT" -lt 50 ]; then
STATUS="${GREEN}SAFE${RESET}"
elif [ "$CPUINT" -lt 75 ]; then
STATUS="${YELLOW}WARNING${RESET}"
else
STATUS="${RED}DANGER${RESET}"
fi

tput cup 20 8
echo -ne "$STATUS"

sleep $INTERVAL

done
