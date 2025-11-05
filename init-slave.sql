-- Espera unos segundos para asegurarse de que el maestro esté listo
DO SLEEP(10);

CHANGE REPLICATION SOURCE TO
  SOURCE_HOST='mysql-master',
  SOURCE_USER='replica',
  SOURCE_PASSWORD='replicapass',
  SOURCE_LOG_FILE='mysql-bin.000001',
  SOURCE_LOG_POS=157,
  GET_SOURCE_PUBLIC_KEY=1;

START REPLICA;
