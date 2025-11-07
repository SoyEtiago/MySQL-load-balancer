# Plan de Pruebas de Rendimiento — MySQL‑load‑balancer (ProxySQL + MySQL)

**Topología (docker‑compose):**
- `proxysql` (6032 admin / 6033 SQL)
- `mysql-master` (writer)
- `mysql-slave1`, `mysql-slave2` (readers)
- `mysql-client` (sysbench + mysql‑client)

**Usuarios:**
- RW: `root/rootpass` (HG10 → master)
- RO: `replica/replicapass` (HG20 → slaves)

---
## Objetivos
1) Medir rendimiento (TPS/QPS) y latencias bajo distintos patrones (lectura, escritura, mixto).  
2) Validar el split de lecturas/escrituras en ProxySQL.  
3) Evaluar escalabilidad de lecturas con 2 réplicas.  
4) Ver tolerancia a fallos (caída de una réplica) y estabilidad en prueba prolongada.

---
## Métricas a recolectar
- **Sysbench:** TPS, QPS, latencia **avg**, **P95**, **P99**, errores/reconnects.  
- **Replicación:** `Seconds_Behind_Master`, `Replica_IO_Running`, `Replica_SQL_Running`.  
- **ProxySQL:** `stats_mysql_connection_pool` (ConnUsed/ConnFree/Queries).  
- **SO (opcional):** `mpstat`, `iostat -x`, `pidstat`.

---
## Parámetros estándar
- `tables=16`, `table-size=1_000_000` (ajustable).  
- `threads ∈ {1,4,8,16,32,64}`; `time=300`; `report-interval=10`.  
- Repetir **3 veces** por escenario y promediar.  
- Dataset: **`sbtest`** (sysbench).

---
## Preparación y limpieza
```bash
# (desde el contenedor mysql-client)
# Crear DB y permisos mínimos
mysql -h proxysql -P6033 -uroot -prootpass \
  -e "CREATE DATABASE IF NOT EXISTS sbtest; \
      GRANT ALL ON sbtest.* TO 'root'@'%'; \
      GRANT SELECT ON sbtest.* TO 'replica'@'%'; FLUSH PRIVILEGES;"

# Poblar dataset (una sola vez al inicio)
sysbench oltp_read_write \
  --db-driver=mysql --mysql-host=proxysql --mysql-port=6033 \
  --mysql-user=root --mysql-password=rootpass --mysql-db=sbtest \
  --tables=16 --table-size=1000000 prepare

# Limpieza al final de todas las campañas
sysbench oltp_read_write \
  --db-driver=mysql --mysql-host=proxysql --mysql-port=6033 \
  --mysql-user=root --mysql-password=rootpass --mysql-db=sbtest \
  --tables=16 --table-size=1000000 cleanup
```

---
## Escenarios (matriz)
### S0 — Baseline (directo al MASTER)
- **S0.1** `oltp_read_only`  
- **S0.2** `oltp_write_only`  
- **S0.3** `oltp_read_write`
> Objetivo: línea base sin balanceador.

### S1 — Lecturas directas a réplicas
- **S1.1** `oltp_read_only` en `mysql-slave1`  
- **S1.2** `oltp_read_only` en `mysql-slave2`
> Objetivo: capacidad individual de cada réplica.

### S2 — ProxySQL con split
- **S2.1** `oltp_read_only` (usuario `replica` sobre `proxysql:6033`)  
- **S2.2** `oltp_write_only` (usuario `root` sobre `proxysql:6033`)  
- **S2.3** `oltp_read_write` (usuario `root` sobre `proxysql:6033`)
> Objetivo: validar reglas, escalado de lecturas y mezcla R/W.

### S3 — Microbench (latencia mínima)
- **S3.1** `oltp_point_select` vía ProxySQL

### S4 — Sensibilidad a tamaño de dataset
- Repetir **S2.1** y **S2.3** con `table-size` menor/igual/mayor al buffer (efecto caché).

### S5 — Tolerancia a fallos
- **S5.1** Durante **S2.1**, detener `mysql-slave2`; observar continuidad y QPS ↓ controlado.  
- **S5.2** Durante **S2.3**, reiniciar `mysql-master`; observar errores y recuperación (si no hay failover).

### S6 — Soak (estabilidad)
- **S6.1** `oltp_read_write` 30–60 min con 16–32 hilos vía ProxySQL.

---
## Ejemplos de comandos **Sysbench** (incluye `oltp_read_write`)
> Ejecutar **desde `mysql-client`**.

### 1) ProxySQL — Lectura/Escritura (S2.3)
```bash
sysbench oltp_read_write \
  --mysql-host=proxysql --mysql-port=6033 \
  --mysql-user=root --mysql-password=rootpass --mysql-db=sbtest \
  --tables=16 --table-size=1000000 \
  --threads=32 --time=300 --report-interval=10 run
```

### 2) ProxySQL — Sólo lecturas (S2.1)
```bash
sysbench oltp_read_only \
  --mysql-host=proxysql --mysql-port=6033 \
  --mysql-user=replica --mysql-password=replicapass --mysql-db=sbtest \
  --tables=16 --table-size=1000000 \
  --threads=32 --time=300 --report-interval=10 run
```

### 3) Baseline MASTER directo (S0.3)
```bash
sysbench oltp_read_write \
  --mysql-host=mysql-master --mysql-port=3306 \
  --mysql-user=root --mysql-password=rootpass --mysql-db=sbtest \
  --tables=16 --table-size=1000000 \
  --threads=32 --time=300 --report-interval=10 run
```

### 4) Point‑select (S3.1)
```bash
sysbench oltp_point_select \
  --mysql-host=proxysql --mysql-port=6033 \
  --mysql-user=replica --mysql-password=replicapass --mysql-db=sbtest \
  --tables=16 --table-size=1000000 \
  --threads=64 --time=300 --report-interval=10 run
```

---
## Monitoreo rápido
```bash
# Lag de réplicas (en el cliente)
mysql -h mysql-slave1 -P3306 -uroot -prootpass -e "SHOW REPLICA STATUS\\G" | egrep "Seconds_Behind_Master|Replica_.*_Running"
mysql -h mysql-slave2 -P3306 -uroot -prootpass -e "SHOW REPLICA STATUS\\G" | egrep "Seconds_Behind_Master|Replica_.*_Running"

# Pool de ProxySQL
mysql -h 127.0.0.1 -P6032 -uadmin -padmin -e \
  "SELECT hostgroup,srv_host,status,ConnUsed,ConnFree,Queries FROM stats_mysql_connection_pool;"
```

---
## Criterios de aceptación (propuestos)
- S2.1 (lecturas vía ProxySQL) ≥ S1.x (réplica individual) en QPS a partir de `threads ≥ 8`.
- Latencias **P95** no empeoran >20% respecto a baseline equivalente.
- En S2.3, `Seconds_Behind_Master` promedio < 2 s y sin errores sostenidos.
- En S5.1, caída de `mysql-slave2` no interrumpe el cliente; sólo reduce QPS.

