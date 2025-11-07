-- Configura permisos para replicación
CREATE USER IF NOT EXISTS 'replica'@'%' IDENTIFIED WITH mysql_native_password BY 'replicapass';
GRANT REPLICATION SLAVE ON *.* TO 'replica'@'%';
FLUSH PRIVILEGES;

-- Crea base de datos de ejemplo
CREATE DATABASE IF NOT EXISTS demo;
USE demo;
CREATE TABLE IF NOT EXISTS test (id INT PRIMARY KEY, msg VARCHAR(100));
INSERT INTO test VALUES (1, 'Fila creada automáticamente en el maestro');
