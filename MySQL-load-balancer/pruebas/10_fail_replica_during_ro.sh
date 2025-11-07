#!/usr/bin/env bash
# 10 — S5.1 Fail a replica during RO test
set -euo pipefail
source ../scripts/common.sh
TAG="S5_1_proxy_ro_fail"
(
  run_sysbench proxysql "$PROXY_SQL_PORT" oltp_read_only "$MYSQL_USER_RO" "$MYSQL_PASS_RO" "$TAG"
) &
SB_PID=$!
sleep $((TIME/2))
log "Stopping mysql-slave2…"
docker stop mysql-slave2 >/dev/null
sleep 10
log "ProxySQL pool after stop:"
proxysql_admin "SELECT hostgroup,srv_host,status,ConnUsed,ConnFree,Queries FROM stats_mysql_connection_pool;" | tee "$LOG_DIR/10_pool_after_stop.log"
wait $SB_PID || true
log "Starting mysql-slave2…"
docker start mysql-slave2 >/dev/null
sleep 10
log "ProxySQL pool after start:"
proxysql_admin "SELECT hostgroup,srv_host,status,ConnUsed,ConnFree,Queries FROM stats_mysql_connection_pool;" | tee "$LOG_DIR/10_pool_after_start.log"
