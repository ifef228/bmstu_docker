CREATE TABLE order_logs(
    id BIGINT PRIMARY KEY generated DEFAULT by identity,
    action_type VARCHAR(16), 
    action_time TIMESTAMP
)

CREATE OR REPLACE FUNCTION log_new_order()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO order_logs (order_id, action, action_time)
    VALUES (NEW.idOrder, 'INSERT', NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_order_insert
AFTER INSERT ON Orders
FOR EACH ROW
EXECUTE FUNCTION log_new_order();

CREATE OR REPLACE FUNCTION prevent_customer_delete()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM Orders WHERE idCustomer = OLD.idCustomer) THEN
        RAISE EXCEPTION 'Нельзя удалить клиента с существующими заказами';
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_customer_delete
BEFORE DELETE ON Customers
FOR EACH ROW
EXECUTE FUNCTION prevent_customer_delete();

CREATE OR REPLACE FUNCTION check_price_update()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.PrPrice <= 0 THEN
        RAISE EXCEPTION 'Цена продукта должна быть положительной';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_product_update
BEFORE UPDATE ON Product
FOR EACH ROW
EXECUTE FUNCTION check_price_update();

CREATE OR REPLACE FUNCTION cascade_delete_product()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM Items WHERE idProduct = OLD.idProduct;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_product_delete
BEFORE DELETE ON Product
FOR EACH ROW
EXECUTE FUNCTION cascade_delete_product();

CREATE OR REPLACE FUNCTION calculate_item_total()
RETURNS TRIGGER AS $$
BEGIN
    NEW.Total := NEW.Quantity * (SELECT PrPrice FROM Product WHERE idProduct = NEW.idProduct);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_item_insert_update
BEFORE INSERT OR UPDATE ON Items
FOR EACH ROW
EXECUTE FUNCTION calculate_item_total();

CREATE OR REPLACE FUNCTION protect_tables()
RETURNS event_trigger AS $$
BEGIN
    -- Для PostgreSQL 10+
    IF tg_tag IN ('DROP TABLE', 'ALTER TABLE') THEN
        RAISE EXCEPTION 'Запрещено изменять или удалять таблицы в этой базе данных';
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE EVENT TRIGGER protect_tables_trigger
ON ddl_command_start
EXECUTE FUNCTION protect_tables();

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


-- зыдание по вариантам
--Функция для поиска информации по названию компании
CREATE OR REPLACE FUNCTION get_customer_by_company(company_name VARCHAR(64))
RETURNS TABLE (
    customer_id BIGINT,
    company VARCHAR(64),
    last_name VARCHAR(64),
    first_name VARCHAR(64),
    customer_address VARCHAR(128),
    customer_city VARCHAR(64),
    customer_phone VARCHAR(10),
    customer_email VARCHAR(20)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.idCustomer,
        c.CompanyName,
        c.LastName,
        c.FirstName,
        c.Address,
        c.City,
        c.Phone,
        c.Email
    FROM Customers c
    WHERE c.CompanyName ILIKE '%' || company_name || '%';
END;
$$ LANGUAGE plpgsql;


-- Функция для поиска товаров по диапазону цен
CREATE OR REPLACE FUNCTION get_products_by_price_range(min_price DECIMAL, max_price DECIMAL)
RETURNS TABLE (
    product_id BIGINT,
    product_name VARCHAR(16),
    product_price DECIMAL,
    product_in_stock INT,
    product_description VARCHAR(16)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.idProduct,
        p.PrName,
        p.PrPrice,
        p.InStock,
        p.Description
    FROM Product p
    WHERE p.PrPrice BETWEEN min_price AND max_price
    ORDER BY p.PrPrice;
END;
$$ LANGUAGE plpgsql;


--Функция для поиска заказов по датам
CREATE OR REPLACE FUNCTION get_orders_by_dates(
    order_date_from TIMESTAMP DEFAULT NULL,
    order_date_to TIMESTAMP DEFAULT NULL,
    ship_date_from TIMESTAMP DEFAULT NULL,
    ship_date_to TIMESTAMP DEFAULT NULL
)
RETURNS TABLE (
    order_id BIGINT,
    customer_id BIGINT,
    order_date TIMESTAMP,
    ship_date TIMESTAMP,
    order_status VARCHAR(10),
    customer_full_name TEXT  -- Изменено с VARCHAR(128) на TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        o.idOrder,
        o.idCustomer,
        o.orderDate,
        o.ShipDate,
        o.Status,
        c.LastName || ' ' || c.FirstName::TEXT  -- Явное приведение к TEXT
    FROM Orders o
    JOIN Customers c ON o.idCustomer = c.idCustomer
    WHERE 
        (order_date_from IS NULL OR o.orderDate >= order_date_from) AND
        (order_date_to IS NULL OR o.orderDate <= order_date_to) AND
        (ship_date_from IS NULL OR o.ShipDate >= ship_date_from) AND
        (ship_date_to IS NULL OR o.ShipDate <= ship_date_to)
    ORDER BY o.orderDate;
END;
$$ LANGUAGE plpgsql;


--Сгруппированный по городу список заказов за интервал времени
CREATE OR REPLACE FUNCTION get_orders_by_city_and_period(
    date_from TIMESTAMP,
    date_to TIMESTAMP
)
RETURNS TABLE (
    customer_city VARCHAR(64),
    order_id BIGINT,
    order_date TIMESTAMP,
    ship_date TIMESTAMP,
    customer_full_name VARCHAR(128)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.City,
        o.idOrder,
        o.orderDate,
        o.ShipDate,
        (c.LastName || ' ' || c.FirstName)::VARCHAR(128)
    FROM Orders o
    JOIN Customers c ON o.idCustomer = c.idCustomer
    WHERE o.orderDate BETWEEN date_from AND date_to
    ORDER BY c.City, o.ShipDate;
END;
$$ LANGUAGE plpgsql;



--Подсчет количества заказов по городам
CREATE OR REPLACE FUNCTION get_order_count_by_city()
RETURNS TABLE (
    customer_city VARCHAR(64),
    total_orders BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.City,
        COUNT(o.idOrder)::BIGINT
    FROM Customers c
    LEFT JOIN Orders o ON c.idCustomer = o.idCustomer
    GROUP BY c.City
    ORDER BY COUNT(o.idOrder) DESC;
END;
$$ LANGUAGE plpgsql;

--проверка
SELECT * FROM get_customer_by_company('name');

SELECT * FROM get_products_by_price_range(10, 100);

SELECT * FROM get_orders_by_dates('2023-01-01', '2023-12-31');

SELECT * FROM get_orders_by_city_and_period('2023-01-01', '2023-12-31');

SELECT * FROM get_order_count_by_city();


-- доп
--Скалярная функция (расчет общей стоимости заказа)
CREATE OR REPLACE FUNCTION calculate_order_total(order_id BIGINT)
RETURNS DECIMAL AS $$
DECLARE
    total_amount DECIMAL;
BEGIN
    SELECT COALESCE(SUM(i.Quantity * p.PrPrice), 0) 
    INTO total_amount
    FROM Items i
    JOIN Product p ON i.idProduct = p.idProduct
    WHERE i.idOrder = order_id;
    
    RETURN total_amount;
END;
$$ LANGUAGE plpgsql;

--Табличная функция (заказы по клиенту)
CREATE OR REPLACE FUNCTION get_customer_orders(customer_id BIGINT)
RETURNS TABLE (
    order_id BIGINT,
    order_date TIMESTAMP,
    total_amount DECIMAL,
    status VARCHAR(10),
    items_count INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        o.idOrder,
        o.orderDate,
        calculate_order_total(o.idOrder) AS total_amount,
        o.Status,
        (SELECT COUNT(*) FROM Items WHERE idOrder = o.idOrder) AS items_count
    FROM Orders o
    WHERE o.idCustomer = customer_id
    ORDER BY o.orderDate DESC;
END;
$$ LANGUAGE plpgsql;

-- Хранимые процедуры с запросами

-- Процедура 1: Добавление нового товара (исправленная)
CREATE OR REPLACE PROCEDURE add_product(
    p_id BIGINT,
    p_name VARCHAR(16),
    p_price DECIMAL,
    p_stock INT,
    p_desc VARCHAR(16)
) AS $$
BEGIN
    INSERT INTO Product(idProduct, PrName, PrPrice, InStock, Description)
    VALUES (p_id, p_name, p_price, p_stock, p_desc);
END;
$$ LANGUAGE plpgsql;

-- Процедура 2: Обновление статуса заказа (исправленная)
CREATE OR REPLACE PROCEDURE update_order_status(
    o_id BIGINT,
    new_status VARCHAR(10)
) AS $$
BEGIN
    UPDATE Orders
    SET Status = new_status
    WHERE idOrder = o_id;
END;
$$ LANGUAGE plpgsql;

-- Процедура 3: Удаление неактивных клиентов (исправленная)
CREATE OR REPLACE PROCEDURE delete_inactive_customers()
AS $$
BEGIN
    DELETE FROM Customers
    WHERE idCustomer NOT IN (SELECT DISTINCT idCustomer FROM Orders);
END;
$$ LANGUAGE plpgsql;

-- 4. Хранимая процедура для перехвата исключений (исправленная)
CREATE OR REPLACE PROCEDURE safe_product_update(
    p_id BIGINT,
    new_price DECIMAL)
AS $$
BEGIN
    BEGIN
        UPDATE Product
        SET PrPrice = new_price
        WHERE idProduct = p_id;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Ошибка при обновлении товара: %', SQLERRM;
    END;
END;
$$ LANGUAGE plpgsql;


--5. Функции ранжирования (row_number, rank, dense_rank)
-- Пример использования с товарами по цене
SELECT 
    idProduct,
    PrName,
    PrPrice,
    ROW_NUMBER() OVER (ORDER BY PrPrice DESC) AS price_row_number,
    RANK() OVER (ORDER BY PrPrice DESC) AS price_rank,
    DENSE_RANK() OVER (ORDER BY PrPrice DESC) AS price_dense_rank
FROM Product;

-- Пример с клиентами по количеству заказов
SELECT 
    c.idCustomer,
    c.LastName,
    c.FirstName,
    COUNT(o.idOrder) AS order_count,
    ROW_NUMBER() OVER (ORDER BY COUNT(o.idOrder) DESC) AS customer_row_number,
    RANK() OVER (ORDER BY COUNT(o.idOrder) DESC) AS customer_rank,
    DENSE_RANK() OVER (ORDER BY COUNT(o.idOrder) DESC) AS customer_dense_rank
FROM Customers c
LEFT JOIN Orders o ON c.idCustomer = o.idCustomer
GROUP BY c.idCustomer, c.LastName, c.FirstName;

--6. DDL триггер запрета удаления таблиц
CREATE OR REPLACE FUNCTION prevent_table_modification()
RETURNS event_trigger AS $$
BEGIN
    IF tg_tag IN ('DROP TABLE', 'ALTER TABLE') THEN
        RAISE EXCEPTION 'Изменение структуры таблиц запрещено администратором';
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE EVENT TRIGGER protect_tables
ON ddl_command_start
WHEN TAG IN ('DROP TABLE', 'ALTER TABLE')
EXECUTE FUNCTION prevent_table_modification();

--7. DML триггеры
--Триггер BEFORE INSERT (проверка данных перед вставкой заказа)
CREATE OR REPLACE FUNCTION validate_order_before_insert()
RETURNS TRIGGER AS $$
BEGIN
    -- Проверка существования клиента
    IF NOT EXISTS (SELECT 1 FROM Customers WHERE idCustomer = NEW.idCustomer) THEN
        RAISE EXCEPTION 'Клиент с ID % не существует', NEW.idCustomer;
    END IF;
    
    -- Проверка даты заказа
    IF NEW.orderDate > CURRENT_TIMESTAMP THEN
        RAISE EXCEPTION 'Дата заказа не может быть в будущем';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_order_insert
BEFORE INSERT ON Orders
FOR EACH ROW
EXECUTE FUNCTION validate_order_before_insert();

--Триггер AFTER UPDATE (логирование изменений статуса заказа)
CREATE TABLE order_status_log (
    log_id SERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL,
    old_status VARCHAR(10),
    new_status VARCHAR(10),
    change_time TIMESTAMP DEFAULT now(),
    changed_by VARCHAR(32) DEFAULT current_user
);

CREATE OR REPLACE FUNCTION log_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.Status <> OLD.Status THEN
        INSERT INTO order_status_log(order_id, old_status, new_status)
        VALUES (NEW.idOrder, OLD.Status, NEW.Status);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_order_status_update
AFTER UPDATE ON Orders
FOR EACH ROW
EXECUTE FUNCTION log_order_status_change();

--8. Триггер замещения (INSTEAD OF) для представления
-- Создаем представление для сложных операций
-- Создаем представление для сложных операций
CREATE VIEW customer_order_details AS
SELECT 
    c.idCustomer,
    c.LastName,
    c.FirstName,
    c.City,
    o.idOrder,
    o.orderDate,
    o.Status,
    (SELECT SUM(i.Quantity * p.PrPrice) 
     FROM Items i JOIN Product p ON i.idProduct = p.idProduct
     WHERE i.idOrder = o.idOrder) AS total_amount
FROM Customers c
JOIN Orders o ON c.idCustomer = o.idCustomer;

-- Триггер замещения для обновления
CREATE OR REPLACE FUNCTION update_customer_order_details()
RETURNS TRIGGER AS $$
BEGIN
    -- Обновляем данные клиента
    UPDATE Customers SET
        LastName = NEW.LastName,
        FirstName = NEW.FirstName,
        City = NEW.City
    WHERE idCustomer = NEW.idCustomer;
    
    -- Обновляем статус заказа
    UPDATE Orders SET
        Status = NEW.Status
    WHERE idOrder = NEW.idOrder;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER instead_of_update_customer_order
INSTEAD OF UPDATE ON customer_order_details
FOR EACH ROW
EXECUTE FUNCTION update_customer_order_details();

-- Триггер замещения для удаления
CREATE OR REPLACE FUNCTION delete_customer_order_details()
RETURNS TRIGGER AS $$
BEGIN
    -- Удаляем сначала элементы заказа
    DELETE FROM Items WHERE idOrder = OLD.idOrder;
    -- Затем сам заказ
    DELETE FROM Orders WHERE idOrder = OLD.idOrder;
    -- И клиента, если у него больше нет заказов
    IF NOT EXISTS (SELECT 1 FROM Orders WHERE idCustomer = OLD.idCustomer) THEN
        DELETE FROM Customers WHERE idCustomer = OLD.idCustomer;
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER instead_of_delete_customer_order
INSTEAD OF DELETE ON customer_order_details
FOR EACH ROW
EXECUTE FUNCTION delete_customer_order_details();