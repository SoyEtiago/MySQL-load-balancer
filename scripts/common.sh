#!/usr/bin/env bash
set -euo pipefail
# --------------------------------------------------------------------
# Archivo: common.sh
# Descripción:
#   Configuración global y funciones compartidas para las pruebas
#   de rendimiento y balanceo con ProxySQL y MySQL.
# --------------------------------------------------------------------

# -----------------------
# Contenedores Docker
# -----------------------
export PROXY_CONT=proxysql
export CLIENT_CONT=mysql-client
export MASTER_CONT=mysql-master
export SLAVE1_CONT=mysql-slave1
export SLAVE2_CONT=mysql-slave2

# -----------------------
# Puertos de ProxySQL
# -----------------------
export PROXY_SQL_PORT=6033      # Puerto de servicio MySQL de ProxySQL
export PROXY_ADMIN_PORT=6032    # Puerto de administración de ProxySQL

# -----------------------
# Base de datos y usuarios
# -----------------------
export DB=sbtest
export MYSQL_USER_RO=replica
export MYSQL_PASS_RO=replicapass
export MYSQL_USER_RW=root
export MYSQL_PASS_RW=rootpass

# -----------------------
# Parámetros de prueba
# -----------------------
export THREADS_LIST=${THREADS_LIST:-"1 4 8 16 32 64"}  # Número de hilos de prueba
export TIME=${TIME:-300}                               # Duración de cada escenario (segundos)
export RPT=${RPT:-10}                                  # Intervalo de reporte (segundos)
export TABLES=${TABLES:-16}                            # Cantidad de tablas
export TABLE_SIZE=${TABLE_SIZE:-1000000}               # Tamaño de cada tabla (filas)

# -----------------------
# Carpetas de salida
# -----------------------
TS=${TS:-$(date +%F_%H-%M-%S)}
export LOG_DIR=${LOG_DIR:-"logs/${TS}"}
export RES_DIR=${RES_DIR:-"results/${TS}"}
mkdir -p "$LOG_DIR" "$RES_DIR"

# -----------------------
# Funciones auxiliares
# -----------------------

# Mostrar mensaje informativo
log() {
  echo "[INFO] $*"
}

# Ejecutar comando en consola administrativa de ProxySQL
proxysql_admin() {
  docker exec -i "$PROXY_CONT" mysql -h127.0.0.1 -P"$PROXY_ADMIN_PORT" -uadmin -padmin -Nse "$1"
}

# Ejecutar comandos MySQL dentro del contenedor cliente
# Uso:
#   mysql_cli <host> <port> <user> <pass> -e "COMANDO SQL"
mysql_cli() {
  # $1 host  $2 port  $3 user  $4 pass  (args posteriores: -e "...")
  docker exec -i "$CLIENT_CONT" mysql -h "$1" -P "$2" -u"$3" -p"$4" "${@:5}"
}

# Verificar o instalar Sysbench en el contenedor cliente
ensure_sysbench() {
  docker exec -i "$CLIENT_CONT" bash -lc 'command -v sysbench >/dev/null || (apt-get update && apt-get install -y sysbench)'
}

# Ejecutar escenarios de prueba Sysbench
# Uso:
#   run_sysbench <host> <port> <lua_script> <user> <pass> <tag>
# Ejemplo:
#   run_sysbench proxysql 6033 oltp_read_write root rootpass rw_proxy
run_sysbench() {
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
