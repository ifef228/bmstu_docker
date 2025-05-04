-- checks
INSERT INTO Orders(idOrder, idCustomer, Status) VALUES (100, 1, 'NEW');
SELECT * FROM order_logs;

-- Должно вызвать ошибку, если у клиента есть заказы
DELETE FROM Customers WHERE Customers.idCustomer = 1;

-- Должно вызвать ошибку
UPDATE Product SET PrPrice = -5 WHERE idProduct = 1;

-- Сначала добавим товар и позицию заказа
INSERT INTO Product(idProduct, PrName, PrPrice) VALUES (2, 'Test', 100);
INSERT INTO Items(IdItem, idOrder, idProduct, Quantity) VALUES (1, 1, 2, 1);

-- Удаление продукта должно удалить и связанные записи в Items
DELETE FROM Product WHERE idProduct = 2;
SELECT * FROM Items WHERE idProduct = 2; -- Должно быть пусто

-- Должно вызвать ошибку
DROP TABLE Customers;

--проверка задания по вариантам
SELECT * FROM get_customer_by_company('name');

SELECT * FROM get_products_by_price_range(10, 100);

SELECT * FROM get_orders_by_dates('2023-01-01', '2023-12-31');

SELECT * FROM get_orders_by_city_and_period('2023-01-01', '2023-12-31');

SELECT * FROM get_order_count_by_city();

-- проверка доп задания
-- init
-- Очистка таблиц (если нужно)
TRUNCATE TABLE Customers, Orders, Product, Items, order_status_log RESTART IDENTITY CASCADE;

-- Добавляем тестовых клиентов
INSERT INTO Customers (idCustomer, CompanyName, LastName, FirstName, Address, City, IndexCode, Phone, Email)
VALUES 
(1, 'Company A', 'Smith', 'John', 'Address 1', 'New York', 10001, '1234567890', 'john@test.com'),
(2, 'Company B', 'Johnson', 'Mike', 'Address 2', 'Boston', 20002, '2345678901', 'mike@test.com'),
(3, 'Company C', 'Williams', 'Sarah', 'Address 3', 'Chicago', 30003, '3456789012', 'sarah@test.com');

-- Добавляем тестовые товары
INSERT INTO Product (idProduct, PrName, PrPrice, InStock, ReOrder, Description)
VALUES
(1, 'Laptop', 999.99, 10, 'No', 'High-end laptop'),
(2, 'Phone', 699.99, 20, 'No', 'Smartphone'),
(3, 'Tablet', 399.99, 15, 'Yes', 'Budget tablet');

-- Добавляем тестовые заказы
INSERT INTO Orders (idOrder, idCustomer, orderDate, ShipDate, PaidDate, Status)
VALUES
(1, 1, '2023-01-15', '2023-01-20', '2023-01-18', 'Completed'),
(2, 1, '2023-02-10', '2023-02-15', '2023-02-12', 'Completed'),
(3, 2, '2023-03-05', NULL, NULL, 'Processing');

-- Добавляем элементы заказов
INSERT INTO Items (IdItem, idOrder, idProduct, Quantity, Total)
VALUES
(1, 1, 1, 1, 999.99),
(2, 1, 2, 2, 1399.98),
(3, 2, 3, 3, 1199.97),
(4, 3, 1, 1, 999.99);


-- проверка доп задания
-- Тестирование функций ранжирования (п.5)
-- Тест 5.1: Ранжирование товаров по цене
SELECT 
    idProduct,
    PrName,
    PrPrice,
    ROW_NUMBER() OVER (ORDER BY PrPrice DESC) AS price_row_number,
    RANK() OVER (ORDER BY PrPrice DESC) AS price_rank,
    DENSE_RANK() OVER (ORDER BY PrPrice DESC) AS price_dense_rank
FROM Product;

/* Ожидаемый результат:
idproduct | prname | prprice | price_row_number | price_rank | price_dense_rank
----------+--------+---------+------------------+------------+-----------------
1        | Laptop | 999.99  | 1                | 1          | 1
2        | Phone  | 699.99  | 2                | 2          | 2
3        | Tablet | 399.99  | 3                | 3          | 3
*/

-- Тест 5.2: Ранжирование клиентов по количеству заказов
SELECT 
    c.idCustomer,
    c.LastName,
    COUNT(o.idOrder) AS order_count,
    ROW_NUMBER() OVER (ORDER BY COUNT(o.idOrder) DESC) AS row_num,
    RANK() OVER (ORDER BY COUNT(o.idOrder) DESC) AS rank_val,
    DENSE_RANK() OVER (ORDER BY COUNT(o.idOrder) DESC) AS dense_rank_val
FROM Customers c
LEFT JOIN Orders o ON c.idCustomer = o.idCustomer
GROUP BY c.idCustomer, c.LastName;

/* Ожидаемый результат:
idcustomer | lastname | order_count | row_num | rank_val | dense_rank_val
-----------+----------+-------------+---------+----------+---------------
1         | Smith    | 2           | 1       | 1        | 1
2         | Johnson  | 1           | 2       | 2        | 2
3         | Williams | 0           | 3       | 3        | 3
*/


-- Тестирование DDL триггера (п.6)
-- Тест 6.1: Попытка удаления таблицы (должна вызвать ошибку)
DROP TABLE Customers;

/* Ожидаемый результат:
ОШИБКА:  Изменение структуры таблиц запрещено администратором
*/

-- Тест 6.2: Попытка изменения таблицы (должна вызвать ошибку)
ALTER TABLE Orders ADD COLUMN test_column INT;

/* Ожидаемый результат:
ОШИБКА:  Изменение структуры таблиц запрещено администратором
*/


-- Тестирование DML триггеров (п.7)
-- Тест 7.1: Проверка BEFORE INSERT триггера (невалидный клиент)
INSERT INTO Orders (idOrder, idCustomer, orderDate, Status)
VALUES (4, 999, '2023-04-01', 'New');

/* Ожидаемый результат:
ОШИБКА:  Клиент с ID 999 не существует
*/

-- Тест 7.2: Проверка AFTER UPDATE триггера (логирование изменений)
-- Сначала посмотрим текущие логи
SELECT * FROM order_status_log;

-- Меняем статус заказа
UPDATE Orders SET Status = 'Shipped' WHERE idOrder = 3;

-- Проверяем логи
SELECT * FROM order_status_log;

/* Ожидаемый результат в логах:
log_id | order_id | old_status | new_status | change_time          | changed_by
-------+----------+------------+------------+---------------------+-----------
1      | 3        | Processing | Shipped    | [текущая дата-время] | [текущий пользователь]
*/

--Тестирование триггеров замещения (п.8)
-- Тест 8.1: Обновление через представление
UPDATE customer_order_details 
SET LastName = 'Smith-Jones', Status = 'Cancelled' 
WHERE idOrder = 1;

-- Проверяем изменения
SELECT * FROM Customers WHERE idCustomer = 1;
SELECT * FROM Orders WHERE idOrder = 1;

/* Ожидаемый результат:
В Customers: LastName = 'Smith-Jones'
В Orders: Status = 'Cancelled'
*/

-- Тест 8.2: Удаление через представление
DELETE FROM customer_order_details WHERE idOrder = 2;

-- Проверяем удаление
SELECT * FROM Orders WHERE idOrder = 2;
SELECT * FROM Items WHERE idOrder = 2;

/* Ожидаемый результат:
Запись с idOrder = 2 должна отсутствовать в Orders и Items
*/