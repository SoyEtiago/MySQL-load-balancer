#!/usr/bin/env bash
set -e
echo "Containers:"
docker ps --format '{{.Names}}\t{{.Status}}'
echo; echo "ProxySQL servers"
docker exec -i proxysql mysql -uadmin -padmin -h127.0.0.1 -P6032 -e "SELECT hostgroup_id, hostname, port, status FROM runtime_mysql_servers;"
echo; echo "ProxySQL pool stats"
docker exec -i proxysql mysql -uadmin -padmin -h127.0.0.1 -P6032 -e "SELECT hostgroup, srv_host, Queries, ConnUsed FROM stats_mysql_connection_pool;"
echo; echo "Master status"
docker exec -i mysql-master mysql -uroot -prootpass -e "SHOW MASTER STATUS\G"
echo; echo "Slave1 status"
docker exec -i mysql-slave1 mysql -uroot -prootpass -e "SHOW SLAVE STATUS\G"
echo; echo "Slave2 status"
docker exec -i mysql-slave2 mysql -uroot -prootpass -e "SHOW SLAVE STATUS\G"
