-------------------------------------------------------
Задание логическое резервное копирование
-------------------------------------------------------
1. Подготовка исходного сервера
для начала надо создать 2 тестовые бд:
```sql
CREATE DATABASE db1;
CREATE DATABASE db2;
```

заполнение тестовыми данными:
```sql
\c db1
CREATE TABLE customers (id SERIAL PRIMARY KEY, name VARCHAR(100));
CREATE VIEW active_customers AS SELECT * FROM customers WHERE id < 100;
CREATE INDEX idx_customers_name ON customers(name);
INSERT INTO customers (name) VALUES ('Alice'), ('Bob');

```

```sql
\c db2
CREATE TABLE products (id SERIAL PRIMARY KEY, title TEXT, price DECIMAL(10,2));
CREATE MATERIALIZED VIEW expensive_products AS SELECT * FROM products WHERE price > 1000;
INSERT INTO products (title, price) VALUES ('Laptop', 1500), ('Phone', 800);
```

2. Резервное копирование глобальных данных
далее зайти в терминал докер контейнера и написать следующие команды:
(резервное копирование глобольных объектов - роли, табличные пространства)
```bash
pg_dumpall -U user -g > global.sql
```

проверяем, что программа сработала (результатом является содержимое файла):
```bash
head -n 100 global.sql   
```
3. Параллельное резервное копирование баз данных 
далее создаем отдельные дампы для каждой бд:
```bash
# Для db1 (4 потока)
pg_dump -Fd -j 4 -U user -f db1_dump db1

# Для db2 (4 потока)
pg_dump -Fd -j 4 -U user -f db2_dump db2
```

для проверки запустим команды:
```bash
ls -lh db1_dump/

ls -lh db2_dump/
```

на каждую из команд должно вывести примерно следующее:
```bash
-rw-r--r-- 1 root root   51 Apr 27 14:08 2939.dat.gz
-rw-r--r-- 1 root root 2.8K Apr 27 14:08 toc.dat
```

4. Восстановление на новом сервере
-для начала создадим еще один докер - контейнер на другом хосте (код есть в папке doker_scripts)
-копируем файлы из папки backup в такую же папку в новом контейнере с помощью следующих команд:
```PowerShell
docker cp b50b8f2d331faa6adb3e485650063fb48b69de01a956cdc0e6807c7ad222417c:/backup/. ./temp_backup/

docker cp ./temp_backup/. 6956951eba33c049bc1b13e682084ecff5181bba6b5acf00f653a55ef9802b90:/backup/

rm ./temp_backup
```

-восстанавливаем глобальные данные следующей командой:
```bash
psql -U user -d postgres -f global.sql
```
-в новом контейнере создадим пустые бд:
```bash
psql -U user -d postgres -c "CREATE DATABASE db1;"
psql -U user -d postgres -c "CREATE DATABASE db2;"
```
-восстанавливаем данные в бд:
```bash
pg_restore -U user -d db1 -j 4 /backup/db1_dump
pg_restore -U user -d db1 -j 4 /backup/db2_dump
```
-подключимся к базе через терминал и проверим данные:
```PowerShell
docker exec -it docker_script-master_postgres-1 psql -U user -d db1

 select * from users;
 select * from products;
```

-в ответ получим исходные таблицы:
```PowerShell
 id | name  |       email
----+-------+-------------------
  1 | Alice | alice@example.com
  2 | Bob   | bob@example.com
(2 rows)


 id | title  | price
----+--------+--------
  1 | Laptop | 999.99
  2 | Phone  | 699.99
```

-------------------------------------------------------
Задание физическое резервное копирование
-------------------------------------------------------
1. Создадим в первом кластере табличное пространство и базу данных с таблицей в этом пространстве:
```bash
mkdir -p /var/lib/postgresql/tablespaces/ts1
chown postgres:postgres /var/lib/postgresql/tablespaces/ts1# 
```

```sql
create tablespace ts1 location '/var/lib/postgresql/tablespaces/ts1';

create database db_in_ts1 with tablespace ts1;
```
-подключимся к базе db_in_ts1 и создадим там тестовую таблицу и вставим туда тестовые данные:
```sql
CREATE TABLE test_table (id SERIAL PRIMARY KEY, data TEXT);
INSERT INTO test_table (data) VALUES ('Test data in tablespace');
```

2. Создание базовой резервной копии с pg_basebackup
-Создание резервной копии в формате .tar.gz
```bash
pg_basebackup -U postgres -D /backup/postgres_backup -Ft -z -Xs -P
```

3. Развертывание второго кластера
-подготовка каталога данных на другом контейнере
```bash
mkdir -p /var/lib/postgresql_new/data
chown postgres:postgres /var/lib/postgresql_new/data
```

-копирование папок в другой контейнер
```PowerShell
docker cp b50b8f2d331faa6adb3e485650063fb48b69de01a956cdc0e6807c7ad222417c:/backup/. ./temp_backup/

docker cp ./temp_backup/. 6956951eba33c049bc1b13e682084ecff5181bba6b5acf00f653a55ef9802b90:/backup/

rm ./temp_backup
```

-Распаковка резервной копии
```bash
tar -xzf /backup/postgres_backup/base.tar.gz -C /var/lib/postgresql_new/data
tar -xzf /backup/postgres_backup/pg_wal.tar.gz -C /var/lib/postgresql_new/data/pg_wal
```

-Создаем файл tablespace_mapping.conf:
```bash
/var/lib/postgresql/tablespaces/ts1 /var/lib/postgresql_new/tablespaces/ts1_new
```