#!/usr/bin/env bash
# 05 — S3.1 Point select via ProxySQL
set -eu
if (set -o pipefail) 2>/dev/null; then set -o pipefail; fi
source ../scripts/common.sh
run_sysbench proxysql "$PROXY_SQL_PORT" oltp_point_select "$MYSQL_USER_RO" "$MYSQL_PASS_RO" "S3_1_proxy_point"
