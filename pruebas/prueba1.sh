#!/usr/bin/env bash
# ============================================
# Prueba 1 — Lecturas a través de ProxySQL
# Objetivo: comprobar funcionamiento del balanceador para SELECTs
# ============================================

set -e
echo "=== PRUEBA 1: LECTURAS A TRAVÉS DE PROXYSQL ==="

LOG="logs/prueba_lectura_$(date +%F_%H-%M-%S).log"
mkdir -p logs

echo "[INFO] Ejecutando consulta de lectura sobre ProxySQL (replica user)..."
docker exec -i mysql-client mysql -h proxysql -P6033 \
  -ureplica -preplicapass -e "USE demo; SELECT COUNT(*) AS total_filas FROM test;" | tee "$LOG"

echo "[INFO] Consultando distribución de lecturas en ProxySQL..."
docker exec -i proxysql mysql -uadmin -padmin -h127.0.0.1 -P6032 \
  -e "SELECT hostgroup, srv_host, status, ConnUsed, ConnFree FROM stats_mysql_connection_pool;" | tee -a "$LOG"

echo "[INFO] Prueba de lectura completada."
echo "Logs guardados en: $LOG"
