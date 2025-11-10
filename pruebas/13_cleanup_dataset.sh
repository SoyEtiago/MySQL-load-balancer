#!/usr/bin/env bash
# 13 — Cleanup sbtest dataset
set -eu
if (set -o pipefail) 2>/dev/null; then set -o pipefail; fi
source ../scripts/common.sh
docker exec -i "$CLIENT_CONT" bash -lc "sysbench oltp_read_write \
  --db-driver=mysql --mysql-host=proxysql --mysql-port=$PROXY_SQL_PORT \
  --mysql-user=$MYSQL_USER_RW --mysql-password=$MYSQL_PASS_RW --mysql-db=$DB \
  --tables=$TABLES --table-size=$TABLE_SIZE cleanup" | tee "$LOG_DIR/13_cleanup.log"
