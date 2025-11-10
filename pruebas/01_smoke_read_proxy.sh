#!/usr/bin/env bash
# 01 — Smoke read through ProxySQL (RO) and pool status
set -eu
if (set -o pipefail) 2>/dev/null; then set -o pipefail; fi
source ../scripts/common.sh

log "SELECT via ProxySQL (replica)"
mysql_cli proxysql "$PROXY_SQL_PORT" "$MYSQL_USER_RO" "$MYSQL_PASS_RO" -e "SELECT COUNT(*) total FROM information_schema.tables;" | tee "$LOG_DIR/01_ro_smoke.sql.log"

log "ProxySQL pool status"
proxysql_admin "SELECT hostgroup,srv_host,status,ConnUsed,ConnFree,Queries FROM stats_mysql_connection_pool;" | tee -a "$LOG_DIR/01_ro_smoke.sql.log"
