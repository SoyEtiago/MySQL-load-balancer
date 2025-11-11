# MySQL Load Balancer — ProxySQL + MySQL (Docker) 🧪⚡

Balanceador de **lecturas** con **ProxySQL** frente a un clúster MySQL **1 master (writes) + 2 slaves (reads)**.
Incluye **scripts de pruebas** con **Sysbench** y guías para verificar **rendimiento**, **lag de replicación** y **tolerancia a fallos**.

---

## 🧱 Topología (docker-compose)
Servicios:
- `proxysql` (admin `6032`, SQL `6033`)
- `mysql-master` (writer)
- `mysql-slave1`, `mysql-slave2` (readers)
- `mysql-client` (sysbench + mysql-client)

Usuarios y credenciales por defecto:
- **RW** (master / ProxySQL HG10): `root / rootpass`
- **RO** (slaves / ProxySQL HG20): `replica / replicapass`

> Asegúrate de que tu `proxysql.cnf` tenga las reglas de split:
> - SELECT → hostgroup 20 (slaves)
> - Otros (INSERT/UPDATE/DELETE) → hostgroup 10 (master)

---

## 🚀 Quick Start
```bash
# Levanta el entorno
docker compose up -d

# Entra al contenedor de cliente (tiene sysbench y mysql-client)
docker exec -it mysql-client bash

# (Dentro del contenedor) permisos y dataset de pruebas
mysql -h proxysql -P6033 -uroot -prootpass   -e "CREATE DATABASE IF NOT EXISTS sbtest;       GRANT ALL ON sbtest.* TO 'root'@'%';       GRANT SELECT ON sbtest.* TO 'replica'@'%'; FLUSH PRIVILEGES;"

sysbench oltp_read_write   --mysql-host=proxysql --mysql-port=6033   --mysql-user=root --mysql-password=rootpass --mysql-db=sbtest   --tables=16 --table-size=1000000 prepare
```

> También podés usar el script `pruebas/00_prepare_dataset.sh` (ver sección **Pruebas**).

---

## 🧪 Escenarios SIN vs CON balanceador

**SIN balanceador (conexión directa a MySQL)**
- **S0 — Baseline MASTER (RO/WO/RW)** → `08_sysbench_baseline_master.sh`
- **S1 — Lecturas directas en réplicas** → `06_sysbench_ro_slave1.sh`, `07_sysbench_ro_slave2.sh`

**CON balanceador (ProxySQL)**  
- **Smoke**: `01_smoke_read_proxy.sh`, `02_smoke_write_proxy.sh`  
- **S2 — Carga OLTP vía ProxySQL**: `03_sysbench_ro_proxy.sh` (RO), `04_sysbench_rw_proxy.sh` (RW)  
- **S3 — Microbench**: `05_sysbench_point_proxy.sh` (point-select)  
- **S4 — Dataset size**: `12_dataset_resize.sh`  
- **S5 — Tolerancia a fallos**: `10_fail_replica_during_ro.sh`  
- **S6 — Soak / estabilidad**: `11_soak_rw_proxy.sh`

---

## 📂 Pruebas (scripts) y para qué sirven

| Script                             | ¿Qué valida?                                                             | ¿Para qué te sirve en el proyecto?                                                                                           |
| ---------------------------------- | ------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------- |
| **00_prepare_dataset.sh**          | Crea y puebla `sbtest`.                                                  | Tener un dataset realista y repetible para comparar escenarios.                                                              |
| **01_smoke_read_proxy.sh**         | Que los `SELECT` entran por ProxySQL y van a las réplicas (pool ONLINE). | Confirmar que el **split de lecturas** funciona antes de hacer carga pesada.                                                 |
| **02_smoke_write_proxy.sh**        | Que los **writes** van al **maestro** y se **replican** a ambos slaves.  | Asegurar **consistencia** básica y replicación OK.                                                                           |
| **03_sysbench_ro_proxy.sh**        | Rendimiento **read-only** balanceado por ProxySQL.                       | Medir la **ganancia de escalado** con 2 réplicas vs 1 sola; decidir **pesos/hostgroups**.                                    |
| **04_sysbench_rw_proxy.sh**        | Carga **mixta R/W** con split (SELECT→slaves, write→master).             | Ver **TPS/QPS** “de verdad”, revisar **P95/P99** y **lag**; ajustar reglas de ProxySQL o parámetros de MySQL si el lag sube. |
| **05_sysbench_point_proxy.sh**     | Latencia mínima de `point_select` vía Proxy.                             | Medir la **sobrecarga del proxy**; afinar pooling/conexiones si hay latencias altas.                                         |
| **06_sysbench_ro_slave1.sh**       | Capacidad de **slave1** directo.                                         | Línea base por réplica; detectar asimetrías de CPU/IO/latencia.                                                              |
| **07_sysbench_ro_slave2.sh**       | Capacidad de **slave2** directo.                                         | Igual que 06 para comparar y ajustar **pesos** en ProxySQL.                                                                  |
| **08_sysbench_baseline_master.sh** | Línea base en **master** (RO/WO/RW).                                     | Saber el **techo de writes** y el costo (overhead) del proxy frente a conexión directa.                                      |
| **09_replication_lag_monitor.sh**  | `Seconds_Behind_Master` durante las cargas.                              | Controlar **lag**: si sube, revisar `sync_binlog`, `innodb_flush_log_at_trx_commit`, red, o considerar **semi-sync**.        |
| **10_fail_replica_during_ro.sh**   | Caída de una réplica en mitad de lecturas.                               | Validar **tolerancia a fallos**: el servicio debe seguir; ajustar **health-checks** y tiempos de shun/recover en ProxySQL.   |
| **11_soak_rw_proxy.sh**            | Carga larga (30–60 min) R/W.                                             | Ver **estabilidad**: sin fugas de memoria, sin drift de P95 ni crecimiento de lag.                                           |
| **12_dataset_resize.sh**           | Dataset que **cabe/no cabe** en caché.                                   | Entender efecto de **caché** y dimensionar **RAM/buffer pool**.                                                              |
| **13_cleanup_dataset.sh**          | Limpia `sbtest`.                                                         | Deja el entorno limpio para nuevas campañas.                                                                                 |
| **run_matrix.sh**                  | Orquesta 03, 04, 05 y 08.                                                | Correr la **muestra representativa** con un solo comando y recolectar logs comparables.                                      |

> **Tips de lectura:** revisa `results/<timestamp>/*.log` para `transactions:`, `queries:`, `avg:`, `95th percentile:`, `99th percentile:` y `errors:`.

---

## 🧭 Flujo recomendado
```bash
# Dar permisos de ejecución
chmod +x pruebas/*.sh scripts/*.sh

# 1) Preparar dataset
./pruebas/00_prepare_dataset.sh

# 2) Validaciones rápidas (smoke)
./pruebas/01_smoke_read_proxy.sh
./pruebas/02_smoke_write_proxy.sh

# 3) Matriz principal (RO, RW, point-select + baseline master)
./pruebas/run_matrix.sh

# 4) (Opcional) Monitor de lag en paralelo
./pruebas/09_replication_lag_monitor.sh 5

# 5) (Opcional) Fallo controlado de réplica durante lecturas
TIME=60 THREADS_LIST="4" ./pruebas/10_fail_replica_during_ro.sh

# 6) Limpieza al final
./pruebas/13_cleanup_dataset.sh
```

---

## 🔍 Verificación “antes/después” en slave1 (Com_select)
Ejecuta esto **fuera** del contenedor de cliente (o usando `docker exec -i mysql-client ...`):

```bash
# Antes
docker exec -it mysql-master mysql -uroot -prootpass -Nse "SHOW GLOBAL STATUS LIKE 'Com_select';"
docker exec -it mysql-slave1 mysql -uroot -prootpass -Nse "SHOW GLOBAL STATUS LIKE 'Com_select';"

# Corre la prueba directa al slave1 (10s, 4 hilos)
TIME=10 THREADS_LIST="4" bash ./pruebas/06_sysbench_ro_slave1.sh

# Después
docker exec -it mysql-master mysql -uroot -prootpass -Nse "SHOW GLOBAL STATUS LIKE 'Com_select';"
docker exec -it mysql-slave1 mysql -uroot -prootpass -Nse "SHOW GLOBAL STATUS LIKE 'Com_select';"
```

Deberías ver **incremento** en `Com_select` del **slave1** y no en el master para esta prueba.

---

## 🧰 Ajustes rápidos (env vars útiles)
Todos los scripts aceptan sobrescribir variables vía **entorno**:

- `TIME` (segundos, por defecto 300)  
- `THREADS_LIST` (concurrencias, por defecto `1 4 8 16 32 64`)  
- `TABLES` y `TABLE_SIZE` (tamaño de dataset)  

**Ejemplos:**
```bash
# 60s, 4 hilos, sólo lecturas por ProxySQL
TIME=60 THREADS_LIST="4" bash ./pruebas/03_sysbench_ro_proxy.sh

# RW prolongado (soak) con 16/32 hilos
TIME=3600 THREADS_LIST="16 32" bash ./pruebas/11_soak_rw_proxy.sh
```

> **Sólo SELECT sin transacciones**: los scripts usan el perfil por defecto de sysbench (con BEGIN/COMMIT).  
> Si querés emular *solo selects* aún más “finos”, podés correr **sysbench directo** con `--skip_trx=on`:
> ```bash
> docker exec -it mysql-client bash -lc 'sysbench oltp_read_only >   --mysql-host=proxysql --mysql-port=6033 >   --mysql-user=replica --mysql-password=replicapass --mysql-db=sbtest >   --tables=16 --table-size=1000000 --threads=4 --time=60 --skip_trx=on run'
> ```

---

## 📊 Métricas clave a reportar
- **TPS/QPS** y **latencias** (**avg**, **P95**, **P99**)
- **Lag** (`Seconds_Behind_Master`) en slaves durante **S2.3** y **S6.1**
- **Tolerancia a fallos**: continuidad del servicio en **S5.1**

---

## 📦 Estructura de carpetas (salidas)
- `results/<timestamp>/` — logs de sysbench por escenario/hilos
- `logs/<timestamp>/` — pool ProxySQL, lag de replicación, eventos de fallos

---

## 📚 Referencia rápida de comandos Sysbench (OLTP)
```bash
# Lectura/Escritura por ProxySQL (S2.3)
sysbench oltp_read_write --mysql-host=proxysql --mysql-port=6033   --mysql-user=root --mysql-password=rootpass --mysql-db=sbtest   --tables=16 --table-size=1000000 --threads=32 --time=300 run

# Sólo lecturas por ProxySQL (S2.1)
sysbench oltp_read_only --mysql-host=proxysql --mysql-port=6033   --mysql-user=replica --mysql-password=replicapass --mysql-db=sbtest   --tables=16 --table-size=1000000 --threads=32 --time=300 run

# Baseline master directo (S0.3)
sysbench oltp_read_write --mysql-host=mysql-master --mysql-port=3306   --mysql-user=root --mysql-password=rootpass --mysql-db=sbtest   --tables=16 --table-size=1000000 --threads=32 --time=300 run
```

---

¡Listo! Con esto tenés un **README** claro para ejecutar, medir y presentar resultados del proyecto.
