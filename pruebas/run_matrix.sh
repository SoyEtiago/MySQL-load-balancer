#!/usr/bin/env bash
# Run main matrix and save results
set -eu
if (set -o pipefail) 2>/dev/null; then set -o pipefail; fi
source scripts/common.sh
./pruebas/03_sysbench_ro_proxy.sh
./pruebas/04_sysbench_rw_proxy.sh
./pruebas/05_sysbench_point_proxy.sh
./pruebas/08_sysbench_baseline_master.sh
log "DONE → results in ${RES_DIR} and logs in ${LOG_DIR}"
