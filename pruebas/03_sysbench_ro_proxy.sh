#!/usr/bin/env bash
# 03 — S2.1 Read-only via ProxySQL
set -eu
if (set -o pipefail) 2>/dev/null; then set -o pipefail; fi
source ../scripts/common.sh
run_sysbench proxysql "$PROXY_SQL_PORT" oltp_read_only "$MYSQL_USER_RO" "$MYSQL_PASS_RO" "S2_1_proxy_ro"
