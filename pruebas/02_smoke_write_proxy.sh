#!/usr/bin/env bash
# 02 — Smoke write via ProxySQL (RW) and check on slaves
set -eu
if (set -o pipefail) 2>/dev/null; then set -o pipefail; fi
source ../scripts/common.sh

mysql_cli proxysql "$PROXY_SQL_PORT" "$MYSQL_USER_RW" "$MYSQL_PASS_RW" -e "CREATE TABLE IF NOT EXISTS $DB.healthcheck(id INT PRIMARY KEY AUTO_INCREMENT, ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP); INSERT INTO $DB.healthcheck() VALUES();"

log "Read latest on slave1"
mysql_cli mysql-slave1 3306 root rootpass -e "SELECT COUNT(*) c, MAX(ts) last_ts FROM $DB.healthcheck;" | tee "$LOG_DIR/02_rw_smoke.slave1.log"

log "Read latest on slave2"
mysql_cli mysql-slave2 3306 root rootpass -e "SELECT COUNT(*) c, MAX(ts) last_ts FROM $DB.healthcheck;" | tee "$LOG_DIR/02_rw_smoke.slave2.log"
