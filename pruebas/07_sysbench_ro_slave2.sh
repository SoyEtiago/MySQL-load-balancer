#!/usr/bin/env bash
# 07 — S1.2 Read-only direct to slave2
set -euo pipefail
source scripts/common.sh
run_sysbench mysql-slave2 3306 oltp_read_only root rootpass "S1_2_slave2_ro"
