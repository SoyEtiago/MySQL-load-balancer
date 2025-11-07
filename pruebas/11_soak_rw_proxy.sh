#!/usr/bin/env bash
# 11 — S6.1 Soak test RW via ProxySQL (30–60 min)
set -euo pipefail
source scripts/common.sh
export TIME=${TIME:-3600}
export THREADS_LIST=${THREADS_LIST:-"16 32"}
run_sysbench proxysql "$PROXY_SQL_PORT" oltp_read_write "$MYSQL_USER_RW" "$MYSQL_PASS_RW" "S6_1_proxy_rw_soak"
