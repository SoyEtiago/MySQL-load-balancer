#!/usr/bin/env bash
set -euo pipefail

# Containers (docker-compose)
export PROXY_CONT=proxysql
export CLIENT_CONT=mysql-client
export MASTER_CONT=mysql-master
export SLAVE1_CONT=mysql-slave1
export SLAVE2_CONT=mysql-slave2

# Ports
export PROXY_SQL_PORT=6033
export PROXY_ADMIN_PORT=6032

# Database and users
export DB=sbtest
export MYSQL_USER_RO=replica
export MYSQL_PASS_RO=replicapass
export MYSQL_USER_RW=root
export MYSQL_PASS_RW=rootpass

# Test parameters (override via env)
export THREADS_LIST=${THREADS_LIST:-"1 4 8 16 32 64"}
export TIME=${TIME:-300}
export RPT=${RPT:-10}
export TABLES=${TABLES:-16}
export TABLE_SIZE=${TABLE_SIZE:-1000000}

# Output folders
TS=${TS:-$(date +%F_%H-%M-%S)}
export LOG_DIR=${LOG_DIR:-"logs/${TS}"}
export RES_DIR=${RES_DIR:-"results/${TS}"}
mkdir -p "$LOG_DIR" "$RES_DIR"

log(){ echo "[INFO] $*"; }

proxysql_admin(){
  docker exec -i "$PROXY_CONT" mysql -h127.0.0.1 -P"$PROXY_ADMIN_PORT" -uadmin -padmin -Nse "$1"
}

mysql_cli(){
  # $1 host  $2 port  $3 user  $4 pass  (optional args after: -e "...")
  docker exec -i "$CLIENT_CONT" mysql -h "$1" -P "$2" -u"$3" -p"$4" "${5:-}"
}

ensure_sysbench(){
  docker exec -i "$CLIENT_CONT" bash -lc 'command -v sysbench >/dev/null || (apt-get update && apt-get install -y sysbench)'
}

run_sysbench(){
  # $1 host  $2 port  $3 lua  $4 user  $5 pass  $6 tag
  local host=$1 port=$2 lua=$3 user=$4 pass=$5 tag=$6
  ensure_sysbench
  for th in $THREADS_LIST; do
    log "sysbench ${lua} → ${host}:${port} threads=${th} time=${TIME}"
    docker exec -i "$CLIENT_CONT" bash -lc "sysbench ${lua} \
      --db-driver=mysql --mysql-host=${host} --mysql-port=${port} \
      --mysql-user=${user} --mysql-password=${pass} --mysql-db=${DB} \
      --tables=${TABLES} --table-size=${TABLE_SIZE} \
      --threads=${th} --time=${TIME} --report-interval=${RPT} --rand-type=uniform run" \
      | tee "${RES_DIR}/${tag}_t${th}.log"
  done
}
