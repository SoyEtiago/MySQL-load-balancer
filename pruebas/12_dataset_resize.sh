#!/usr/bin/env bash
# 12 — S4 Dataset resize and re-prepare
set -eu
if (set -o pipefail) 2>/dev/null; then set -o pipefail; fi
source ../scripts/common.sh
NEW_TABLES=${1:-16}
NEW_TABLE_SIZE=${2:-500000}
log "Cleaning current dataset…"
docker exec -i "$CLIENT_CONT" bash -lc "sysbench oltp_read_write \
  --db-driver=mysql --mysql-host=proxysql --mysql-port=$PROXY_SQL_PORT \
  --mysql-user=$MYSQL_USER_RW --mysql-password=$MYSQL_PASS_RW --mysql-db=$DB \
  --tables=$TABLES --table-size=$TABLE_SIZE cleanup" | tee "$LOG_DIR/12_cleanup.log"
export TABLES=$NEW_TABLES
export TABLE_SIZE=$NEW_TABLE_SIZE
log "Preparing new dataset: tables=$TABLES size=$TABLE_SIZE"
docker exec -i "$CLIENT_CONT" bash -lc "sysbench oltp_read_write \
  --db-driver=mysql --mysql-host=proxysql --mysql-port=$PROXY_SQL_PORT \
  --mysql-user=$MYSQL_USER_RW --mysql-password=$MYSQL_PASS_RW --mysql-db=$DB \
  --tables=$TABLES --table-size=$TABLE_SIZE prepare" | tee "$LOG_DIR/12_prepare_${TABLES}x${TABLE_SIZE}.log"
