1) Реализация ссылочной целостности
Связь уже реализована в твоём init-скрипте:
```sql
CREATE TABLE Customers(
    idCustomer BIGINT PRIMARY KEY,
    ...
    UNIQUE (FirstName, LastName)
);

CREATE TABLE Orders(
    idOrder BIGINT PRIMARY KEY,
    idCustomer BIGINT NOT NULL,
    ...
    FOREIGN KEY (idCustomer) REFERENCES Customers(idCustomer)
);
```

2) Каскадное изменение записей (ON UPDATE CASCADE)
Пусть мы хотим, чтобы при изменении idCustomer в Customers он менялся и в Orders автоматически: 
```sql
alter table orders  drop constraint orders_idcustomer_fkey;

ALTER TABLE orders
ADD CONSTRAINT orders_idcustomer_fkey
FOREIGN KEY (idCustomer) REFERENCES customers(idCustomer)
ON UPDATE CASCADE;
```

3) Каскадное удаление (ON DELETE CASCADE)
Чтобы при удалении покупателя (“Customers”) все его заказы (“Orders”) удалялись автоматически:
```sql
alter table orders  drop constraint orders_idcustomer_fkey;

ALTER TABLE orders
ADD CONSTRAINT orders_idcustomer_fkey
FOREIGN KEY (idCustomer) REFERENCES customers(idCustomer)
ON UPDATE CASCADE ON DELETE CASCADE;
```

4) Курсоры и процедуры

1.  По названию поставщика выдать названия всех товаров и дату последней поставки. (явный курсор)
- Допустим, Product содержит поле PrName, а связь поставщика с товаром отсутствует. Добавим таблицу Suppliers и поле в товарах:
```sql
-- Пусть Product содержит supplier_id, а Suppliers - idSupplier, SupplierName
CREATE TABLE Suppliers (
    idSupplier BIGINT PRIMARY KEY,
    SupplierName VARCHAR(64) NOT NULL
);

ALTER TABLE Product
ADD COLUMN idSupplier BIGINT REFERENCES Suppliers(idSupplier);

-- Запишем процедуру:
CREATE OR REPLACE FUNCTION get_products_by_supplier(sup_name TEXT)
RETURNS TABLE(product_name TEXT, last_supply DATE) AS $$
DECLARE
    prod_rec RECORD;
    cur_products CURSOR FOR
        SELECT PrName, MAX(ShipDate) AS last_supply
        FROM Product p
        JOIN Items i ON p.idProduct = i.idProduct
        JOIN Orders o ON o.idOrder = i.idOrder
        JOIN Suppliers s ON p.idSupplier = s.idSupplier
        WHERE s.SupplierName = sup_name
        GROUP BY PrName;
BEGIN
    OPEN cur_products;
    LOOP
        FETCH cur_products INTO prod_rec;
        EXIT WHEN NOT FOUND;
        product_name := prod_rec.PrName;
        last_supply  := prod_rec.last_supply;
        RETURN NEXT;
    END LOOP;
    CLOSE cur_products;
END; $$
LANGUAGE plpgsql;
```
- использование: 
```sql
SELECT * FROM get_products_by_supplier('Поставщик_Имя');
```

2. По паре дат выдаёт приход/расход товара (неявный курсор = обычный SELECT FOR в plpgsql)
Добавим поле OperationType в Items (например "in"/"out"). Если его нет, симулируем – расход — отрицательный Quantity.
```sql
CREATE OR REPLACE FUNCTION get_turnover(dt1 DATE, dt2 DATE)
RETURNS TABLE(product_name TEXT, приход INT, расход INT) AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.PrName,
        SUM(CASE WHEN i.Quantity >= 0 THEN i.Quantity ELSE 0 END) AS приход,
        SUM(CASE WHEN i.Quantity <  0 THEN -i.Quantity ELSE 0 END) AS расход
    FROM Items i
    JOIN Product p ON i.idProduct = p.idProduct
    JOIN Orders o ON i.idOrder = o.idOrder
    WHERE o.OrderDate BETWEEN dt1 AND dt2
    GROUP BY p.PrName;
END; $$
LANGUAGE plpgsql;
```

-использование:
```sql
SELECT * FROM get_turnover('2023-01-01', '2024-01-01');
```

3. Увеличить стоимость операций в году на 10% (неявный курсор => UPDATE)
```sql
CREATE OR REPLACE PROCEDURE increase_total_by_year(target_year INT)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE Items i
    SET Total = Total * 1.10
    FROM Orders o
    WHERE i.idOrder = o.idOrder AND EXTRACT(year FROM o.orderDate) = target_year;
END;
$$;
```

- использование:
```sql
CALL increase_total_by_year(2024);
```

4. Для покупателя — каждая 3 операция: бонус 5%
```sql
-- Выбираем ID покупателя по ФИО
CREATE OR REPLACE FUNCTION buyer_bonus(lastn TEXT, firstn TEXT)
RETURNS TABLE("Дата" DATE, "Сумма операции" DECIMAL, "Бонус" DECIMAL) AS $$
DECLARE
    cur_id BIGINT;
    op_rec RECORD;
    n INT := 0;
BEGIN
    SELECT idCustomer INTO cur_id FROM Customers WHERE LastName=lastn AND FirstName=firstn;
    FOR op_rec IN
        SELECT o.PaidDate AS op_date, i.Total AS totalval
        FROM Orders o 
        JOIN Items i ON o.idOrder = i.idOrder
        WHERE o.idCustomer = cur_id
        ORDER BY o.PaidDate
    LOOP
        n := n + 1;
        IF n % 3 = 0 THEN
            RETURN NEXT (op_rec.op_date, op_rec.totalval, op_rec.totalval * 0.05);
        END IF;
    END LOOP;
END; $$
LANGUAGE plpgsql;
```
- использование:
```sql
SELECT * FROM buyer_bonus('Иванов', 'Иван');
```


5. Промежуточные итоги по каждому товару (остаток по датам)
```sql
-- Для простоты: операции по одному товару
CREATE OR REPLACE FUNCTION running_total(dt1 DATE, dt2 DATE)
RETURNS TABLE("Товар" TEXT, "Дата операции" DATE, "Количество" INT, "Промежуточный итог" INT) AS $$
DECLARE
    r RECORD;
    total INT;
BEGIN
    FOR r IN
        SELECT p.PrName, o.orderDate, i.Quantity
        FROM Items i
        JOIN Product p ON i.idProduct = p.idProduct
        JOIN Orders o ON o.idOrder = i.idOrder
        WHERE o.orderDate BETWEEN dt1 AND dt2
        ORDER BY p.PrName, o.orderDate
    LOOP
        IF total IS NULL OR r.PrName <> previous PrName THEN
            total := 0;
        END IF;
        total := total + r.Quantity;
        RETURN NEXT (r.PrName, r.orderDate, r.Quantity, total);
    END LOOP;
END; $$
LANGUAGE plpgsql;
```

- использование:
```sql
SELECT * FROM running_total('2024-01-01', '2024-12-31');
```