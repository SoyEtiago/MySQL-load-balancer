#!/usr/bin/env bash
set -euo pipefail
# --------------------------------------------------------------------
# Archivo: common.sh (mejorado para RO con ProxySQL)
# --------------------------------------------------------------------

# -----------------------
# Contenedores Docker
# -----------------------
export PROXY_CONT=${PROXY_CONT:-proxysql}
export CLIENT_CONT=${CLIENT_CONT:-mysql-client}
export MASTER_CONT=${MASTER_CONT:-mysql-master}
export SLAVE1_CONT=${SLAVE1_CONT:-mysql-slave1}
export SLAVE2_CONT=${SLAVE2_CONT:-mysql-slave2}

# -----------------------
# Puertos de ProxySQL
# -----------------------
export PROXY_SQL_PORT=${PROXY_SQL_PORT:-6033}     # Servicio MySQL de ProxySQL
export PROXY_ADMIN_PORT=${PROXY_ADMIN_PORT:-6032} # Administración de ProxySQL

# -----------------------
# Base de datos y usuarios
# -----------------------
export DB=${DB:-sbtest}
export MYSQL_USER_RO=${MYSQL_USER_RO:-replica}
export MYSQL_PASS_RO=${MYSQL_PASS_RO:-replicapass}
export MYSQL_USER_RW=${MYSQL_USER_RW:-root}
export MYSQL_PASS_RW=${MYSQL_PASS_RW:-rootpass}

# -----------------------
# Parámetros de prueba
# -----------------------
export THREADS_LIST=${THREADS_LIST:-"1 4 8 16 32 64"}  # Concurrencias
export TIME=${TIME:-300}                                # Duración (s)
export RPT=${RPT:-10}                                   # Reporte parcial (s)
export TABLES=${TABLES:-16}                             # Nº tablas
export TABLE_SIZE=${TABLE_SIZE:-1000000}                # Filas/tabla
export RAND_TYPE=${RAND_TYPE:-uniform}                  # uniform/gaussian/special/pareto

# Flags para controlar comportamiento
export SYSBENCH_EXTRA=${SYSBENCH_EXTRA:-}               # Extras libres para sysbench
export RO_SKIP_TRX=${RO_SKIP_TRX:-0}                    # 1 => --skip-trx=on en oltp_read_only
export RO_ENSURE_RULES=${RO_ENSURE_RULES:-0}            # 1 => asegura reglas RO en ProxySQL antes de RO
export RO_TX_PERSIST=${RO_TX_PERSIST:-1}                # 0 => transaction_persistent=0 para usuario RO (opcional)

# -----------------------
# Carpetas de salida
# -----------------------
TS=${TS:-$(date +%F_%H-%M-%S)}
export LOG_DIR=${LOG_DIR:-"logs/${TS}"}
export RES_DIR=${RES_DIR:-"results/${TS}"}
mkdir -p "$LOG_DIR" "$RES_DIR"

# -----------------------
# Utilidades
# -----------------------
log() { echo "[INFO] $*"; }

proxysql_admin() {
  # Ejecuta SQL contra el admin de ProxySQL
  docker exec -i "$PROXY_CONT" mysql -h127.0.0.1 -P"$PROXY_ADMIN_PORT" -uadmin -padmin -Nse "$1"
}

mysql_cli() {
  # mysql_cli <host> <port> <user> <pass> [args mysql...]
  docker exec -i "$CLIENT_CONT" mysql -h "$1" -P "$2" -u"$3" -p"$4" "${@:5}"
}

ensure_sysbench() {
  docker exec -i "$CLIENT_CONT" bash -lc 'command -v sysbench >/dev/null || (apt-get update && apt-get install -y sysbench)'
}

restart_proxysql() {
  log "Reiniciando ProxySQL (limpia contadores de stats)…"
  docker restart "$PROXY_CONT" >/dev/null
}

# Ajusta usuarios y reglas para que las lecturas RO no “peguen” al writer
ensure_ro_rules() {
  log "Ajustando usuario y reglas de ProxySQL para lecturas en réplicas…"

  # Usuario de lectura → hostgroup 20 (réplicas) y transaction_persistent según RO_TX_PERSIST
  proxysql_admin "
    UPDATE mysql_users
      SET default_hostgroup=20, transaction_persistent=${RO_TX_PERSIST}
      WHERE username='${MYSQL_USER_RO}';
    LOAD MYSQL USERS TO RUNTIME; SAVE MYSQL USERS TO DISK;
  "

  # Reglas:
  #  - 0: SELECT ... FOR UPDATE -> 10 (writer)  [prioridad más alta]
  #  - 1: ^SELECT                -> 20 (readers)
  #  - 5-9: BEGIN/COMMIT/ROLLBACK/SET tx -> 20 (para evitar “pegado” en writer)
  #  - 2: .* (catch-all)         -> 10 (writer)
  proxysql_admin "
    DELETE FROM mysql_query_rules WHERE rule_id IN (0,1,2,5,6,7,8,9);
    INSERT INTO mysql_query_rules (rule_id,active,apply,match_pattern,destination_hostgroup) VALUES
      (0, 1,1,'SELECT.*FOR UPDATE',10),
      (1, 1,1,'^SELECT',20),
      (5, 1,1,'^BEGIN',20),
      (6, 1,1,'^COMMIT',20),
      (7, 1,1,'^ROLLBACK',20),
      (8, 1,1,'^SET *autocommit *= *0',20),
      (9, 1,1,'^SET SESSION TRANSACTION',20),
      (2, 1,1,'.*',10);
    LOAD MYSQL QUERY RULES TO RUNTIME; SAVE MYSQL QUERY RULES TO DISK;
  "
}

# -----------------------
# Runner de sysbench
# -----------------------
# run_sysbench <host> <port> <lua_script> <user> <pass> <tag>
run_sysbench() {
  local host=$1 port=$2 lua=$3 user=$4 pass=$5 tag=$6

  # Si es lectura por ProxySQL y pidieron asegurar reglas, hazlo antes
  if [[ "$host" == "proxysql" && "$lua" == "oltp_read_only" && "$RO_ENSURE_RULES" == "1" ]]; then
    ensure_ro_rules
  fi

  ensure_sysbench

  for th in $THREADS_LIST; do
    local extra="${SYSBENCH_EXTRA}"
    # En RO, si piden skip-trx, lo añadimos automáticamente
    if [[ "$lua" == "oltp_read_only" && "$RO_SKIP_TRX" == "1" ]]; then
      extra="--skip-trx=on ${extra}"
    fi

    log "sysbench ${lua} → ${host}:${port} threads=${th} time=${TIME}"
    docker exec -i "$CLIENT_CONT" bash -lc "
      sysbench ${lua} \
        --db-driver=mysql --mysql-host=${host} --mysql-port=${port} \
        --mysql-user=${user} --mysql-password=${pass} --mysql-db=${DB} \
        --tables=${TABLES} --table-size=${TABLE_SIZE} \
        --threads=${th} --time=${TIME} --report-interval=${RPT} \
        --rand-type=${RAND_TYPE} ${extra} run
    " | tee "${RES_DIR}/${tag}_t${th}.log"
  done
}
