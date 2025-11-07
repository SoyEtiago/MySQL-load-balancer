#!/usr/bin/env bash
# 04 — S2.3 Read/Write via ProxySQL
set -euo pipefail
source scripts/common.sh
run_sysbench proxysql "$PROXY_SQL_PORT" oltp_read_write "$MYSQL_USER_RW" "$MYSQL_PASS_RW" "S2_3_proxy_rw"
