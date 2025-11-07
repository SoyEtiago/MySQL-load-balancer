#!/usr/bin/env bash
# 09 — Replication lag monitor (run parallel)
set -euo pipefail
source ../scripts/common.sh
interval=${1:-5}
out="$LOG_DIR/09_replication_lag_$(date +%F_%H-%M-%S).log"
log "Monitoring lag every ${interval}s → $out (CTRL+C to stop)"
while true; do
  echo "--- $(date +%T) ---" | tee -a "$out"
  for h in mysql-slave1 mysql-slave2; do
    echo "[$h]" | tee -a "$out"
    mysql_cli "$h" 3306 root rootpass -e "SHOW REPLICA STATUS\G" | egrep "Seconds_Behind_Master|Replica_IO_Running|Replica_SQL_Running" | tee -a "$out" || true
  done
  sleep "$interval"
done
