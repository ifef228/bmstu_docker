-- каскадное обновление
DROP TABLE IF EXISTS Orders CASCADE;
DROP TABLE IF EXISTS Customers CASCADE;

CREATE TABLE Customers(
    idCustomer BIGINT PRIMARY KEY,
    CompanyName VARCHAR(64),
    ...
);

CREATE TABLE Orders(
    idOrder BIGINT PRIMARY KEY,
    idCustomer BIGINT NOT NULL,
    ...
    FOREIGN KEY (idCustomer) REFERENCES Customers(idCustomer)
        ON UPDATE CASCADE
);

-- каскадное удаление
DROP TABLE IF EXISTS Orders CASCADE;

CREATE TABLE Orders(
    idOrder BIGINT PRIMARY KEY,
    idCustomer BIGINT NOT NULL,
    ...
    FOREIGN KEY (idCustomer) REFERENCES Customers(idCustomer)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);


---------------------------------------------------------
-- Курсоры и процедуры
---------------------------------------------------------
-- По названию поставщика выдать названия всех товаров и дату последней поставки. (явный курсор)
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

