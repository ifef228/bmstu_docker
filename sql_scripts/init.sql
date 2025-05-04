-- 1. Suppliers
INSERT INTO Suppliers(idSupplier, SupplierName)
VALUES
  (1, 'ООО Свет'),
  (2, 'ЗАО АТЛАС'),
  (3, 'Поставка+'),
  (4, 'ТехМаркет'),
  (5, 'Мегастрой'),
  (6, 'РитейлГрупп'),
  (7, 'Дистрибьютор-1'),
  (8, 'ПРОМ+'),
  (9, 'Вега'),
  (10,'Галактика');

-- 2. Customers
INSERT INTO Customers(idCustomer, CompanyName, LastName, FirstName, Address, City, IndexCode, Phone, Email)
VALUES
  (1, 'ООО Ромашка', 'Иванов', 'Петр', 'ул. Ленина, д.1', 'Москва', 101000, '9001111111', 'petrov@test.ru'),
  (2, 'ЗАО Березка', 'Петров', 'Иван', 'ул. Кирова, д.2', 'Санкт-Петербург', 102000, '9002222222', 'ivanov@test.ru'),
  (3, 'ЧП Василек', 'Сидоров', 'Андрей', 'ул. Гагарина, д.3', 'Екатеринбург', 103000, '9003333333', 'sidorov@test.ru'),
  (4, 'ООО Луч', 'Кузнецов', 'Алексей', 'ул. Мира, д.4', 'Новосибирск', 104000, '9004444444', 'kuznecov@test.ru'),
  (5, 'ЗАО Север', 'Попов', 'Сергей', 'ул. Южная, д.5', 'Казань', 105000, '9005555555', 'popov@test.ru'),
  (6, 'ИП Цветок', 'Васильев', 'Игорь', 'ул. Восточная, д.6', 'Челябинск', 106000, '9006666666', 'vasiliev@test.ru'),
  (7, 'ООО Альфа', 'Григорьев', 'Денис', 'ул. Западная, д.7', 'Самара', 107000, '9007777777', 'grigoriev@test.ru'),
  (8, 'ЗАО Орхидея', 'Егоров', 'Владимир', 'ул. Северная, д.8', 'Ростов-на-Дону', 108000, '9008888888', 'egorov@test.ru'),
  (9, 'ЧП Верба', 'Тихонов', 'Борис', 'ул. Новый Мир, д.9', 'Красноярск', 109000, '9009999999', 'tikhonov@test.ru'),
  (10,'ООО Пион', 'Жуков', 'Глеб', 'ул. Победы, д.10', 'Пермь', 110000, '9000000000', 'zhukov@test.ru');

-- 3. Product (учитываем внешний ключ idSupplier)
INSERT INTO Product(idProduct, PrName, PrPrice, InStock, ReOrder, Description, idSupplier)
VALUES
  (1, 'Клавиатура', 1500, 50, '5', 'USB', 1),
  (2, 'Мышь', 650, 40, '4', 'Игровая', 2),
  (3, 'Монитор', 12000, 20, '2', '24"', 3),
  (4, 'Принтер', 7500, 10, '1', 'Лазерный', 4),
  (5, 'Сканер', 5500, 8, '1', 'А4', 5),
  (6, 'Колонки', 2500, 25, '2', '2.0', 6),
  (7, 'Наушники', 1200, 70, '7', 'Микрофон', 7),
  (8, 'Флешка', 800, 100, '10', '32GB', 8),
  (9, 'SSD', 6800, 18, '2', '500GB', 9),
  (10,'Коврик', 500, 33, '3', 'Геймерский',10);

-- 4. Orders (idCustomer 1..10)
INSERT INTO Orders(idOrder, idCustomer, orderDate, ShipDate, PaidDate, Status)
VALUES
  (1, 1, now() - interval '11 days', now() - interval '10 days', now() - interval '9 days', 'paid'),
  (2, 2, now() - interval '9 days', now() - interval '8 days', now() - interval '7 days', 'shipped'),
  (3, 3, now() - interval '7 days', now() - interval '6 days', now() - interval '5 days', 'new'),
  (4, 4, now() - interval '5 days', now() - interval '4 days', now() - interval '3 days', 'paid'),
  (5, 5, now() - interval '3 days', now() - interval '2 days', now() - interval '1 day', 'shipped'),
  (6, 6, now() - interval '12 days', now() - interval '11 days', now() - interval '10 days', 'cancelled'),
  (7, 7, now() - interval '8 days', now() - interval '7 days', now() - interval '6 days', 'paid'),
  (8, 8, now() - interval '4 days', now() - interval '3 days', now() - interval '2 days', 'new'),
  (9, 9, now() - interval '6 days', now() - interval '5 days', now() - interval '4 days', 'shipped'),
  (10,10,now() - interval '2 days', now() - interval '1 day', now(), 'paid');

-- 5. Items (каждый заказ по 1-2 товара)
INSERT INTO Items(IdItem, idOrder, idProduct, Quantity, Total)
VALUES
  (1, 1, 1, 2, 3000),
  (2, 1, 2, 1, 650),
  (3, 2, 3, 1, 12000),
  (4, 3, 4, 2, 15000),
  (5, 4, 5, 1, 5500),
  (6, 5, 6, 1, 2500),
  (7, 6, 7, 4, 4800),
  (8, 7, 8, 5, 4000),
  (9, 8, 9, 1, 6800),
  (10,9, 10, 2, 1000);


-- При необходимости (если ограничения NOT NULL или CHECK на Total/Quantity/цены) - скорректируй значения, чтобы не было отрицательных либо пустых числовых полей.
