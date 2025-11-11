#!/usr/bin/env bash
# 10 — S5.1 Fail a replica during RO test (demo HA sin FATAL)
set -eu
if (set -o pipefail) 2>/dev/null; then set -o pipefail; fi
source ../scripts/common.sh

export RO_ENSURE_RULES=1      # Reaplica reglas: ^SELECT->20; FOR UPDATE->10; BEGIN/COMMIT/SET->20
export RO_SKIP_TRX=1          # Añade --skip-trx=on en oltp_read_only (evita "pegado")
export RO_TX_PERSIST=0        # Permite re-ruteo dentro de la sesión RO
export SYSBENCH_EXTRA="--db-ps-mode=disable --mysql-ignore-errors=all ${SYSBENCH_EXTRA:-}"

# Usa solo un valor de threads (para que run_sysbench no haga varios loops)
export THREADS_LIST="${THREADS_LIST:-8}"
# Duración por defecto si no la das por env
export TIME="${TIME:-60}"

# Si se interrumpe, intenta dejar la réplica arriba
cleanup() {
  docker start mysql-slave2 >/dev/null 2>&1 || true
}
trap cleanup EXIT


# restart_proxysql

TAG="S5_1_proxy_ro_fail"

log "ProxySQL pool (antes):"
proxysql_admin "SELECT hostgroup,srv_host,status,ConnUsed,ConnFree,Queries
                FROM stats_mysql_connection_pool;" | tee "${LOG_DIR}/10_pool_before.log"

# Lanza la carga RO balanceada en background
(
  run_sysbench proxysql "$PROXY_SQL_PORT" oltp_read_only "$MYSQL_USER_RO" "$MYSQL_PASS_RO" "$TAG"
) & SB_PID=$!

# A mitad del tiempo, tumba una réplica
sleep $((TIME/2))
log "Stopping mysql-slave2…"
docker stop -t 0 mysql-slave2 >/dev/null
sleep 8

log "ProxySQL pool after stop:"
proxysql_admin "SELECT hostgroup,srv_host,status,ConnUsed,ConnFree,Queries
                FROM stats_mysql_connection_pool;" | tee "${LOG_DIR}/10_pool_after_stop.log"

# Espera a que termine la carga
wait $SB_PID || true

# Vuelve a levantar la réplica
log "Starting mysql-slave2…"
docker start mysql-slave2 >/dev/null
sleep 10

log "ProxySQL pool after start:"
proxysql_admin "SELECT hostgroup,srv_host,status,ConnUsed,ConnFree,Queries
                FROM stats_mysql_connection_pool;" | tee "${LOG_DIR}/10_pool_after_start.log"

log "DONE: fallo de réplica durante RO demostrado."
