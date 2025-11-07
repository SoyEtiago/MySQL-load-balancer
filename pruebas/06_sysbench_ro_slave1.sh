#!/usr/bin/env bash
# 06 — S1.1 Read-only direct to slave1
set -euo pipefail
source scripts/common.sh
run_sysbench mysql-slave1 3306 oltp_read_only root rootpass "S1_1_slave1_ro"
