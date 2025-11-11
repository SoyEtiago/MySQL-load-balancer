#!/usr/bin/env bash
set -eu
if (set -o pipefail) 2>/dev/null; then set -o pipefail; fi
source ../scripts/common.sh

log "Conectando directo a slave1 y comprobando identidad..."
mysql_cli mysql-slave1 3306 root rootpass -e \
  "SELECT @@hostname AS host, @@server_id AS sid, @@read_only AS ro, @@super_read_only AS sro;"

run_sysbench mysql-slave1 3306 oltp_read_only root rootpass "S1_1_slave1_ro"
