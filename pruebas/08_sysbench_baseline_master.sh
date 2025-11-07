#!/usr/bin/env bash
# 08 — S0 Baseline on master (RO/WO/RW)
set -euo pipefail
source scripts/common.sh
run_sysbench mysql-master 3306 oltp_read_only  root rootpass "S0_master_ro"
run_sysbench mysql-master 3306 oltp_write_only root rootpass "S0_master_wo"
run_sysbench mysql-master 3306 oltp_read_write root rootpass "S0_master_rw"
