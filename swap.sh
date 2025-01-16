#!/bin/bash
#
# 03_swap.sh
# Creates a swap file if not present

set -euo pipefail
source "$(dirname "$0")/env.sh"

SWAPFILE="/swapfile"

echo "=== 03_swap: Checking/creating swap..." | tee -a "$LOG_FILE"

if [ -f "$SWAPFILE" ]; then
  echo "Swap file already exists at $SWAPFILE. Skipping." | tee -a "$LOG_FILE"
else
  echo "Creating swap file..." | tee -a "$LOG_FILE"
  {
    fallocate -l 4G "$SWAPFILE"
    chmod 600 "$SWAPFILE"
    mkswap "$SWAPFILE"
    swapon "$SWAPFILE"
    echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
    echo 'vm.swappiness=10' | tee -a /etc/sysctl.conf
    sysctl -p
  } 2>&1 | tee -a "$LOG_FILE"
fi

echo "=== 03_swap: Done." | tee -a "$LOG_FILE"
