
CREATE TABLE Customers(
                          idCustomer BIGINT PRIMARY KEY,
                          CompanyName VARCHAR(64),
                          LastName VARCHAR(64) NOT NULL,
                          FirstName VARCHAR(64) NOT NULL,
                          Address VARCHAR(128),
                          City VARCHAR(64),
                          IndexCode INT,
                          Phone VARCHAR(10),
                          Email VARCHAR(20),

                          unique (FirstName, LastName)
);

CREATE TABLE Orders(
                       idOrder BIGINT PRIMARY KEY,
                       idCustomer bigint NOT NULL,
                       orderDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                       ShipDate TIMESTAMP,
                       PaidDate TIMESTAMP,
                       Status Varchar(10),

                       FOREIGN KEY (idCustomer) REFERENCES "Customers"("idCustomer")
);

alter table orders add constraint dateConstraint  check ( orderDate > current_timestamp - interval '1 year');

create table Product(
                        idProduct BIGINT primary key,
                        PrName varchar(16) not null,
                        PrPrice int check ( PrPrice > 0 ),
                        InStock int,
                        ReOrder varchar(16),
                        Description varchar(16)
);

alter table Product alter column PrPrice set data type decimal;
alter table Product add constraint price check ( prprice > 0 );

create table Items(
                      IdItem BIGINT primary key,
                      idOrder bigint not null,
                      idProduct bigint not null,
                      Quantity int not null,
                      Total decimal,

                      foreign key (idOrder) references Orders(idOrder),
                      foreign key (idProduct) references Product(idProduct)
);

insert into Orders(idOrder, idCustomer, orderDate, ShipDate, PaidDate, Status)
VALUES (1, 1, now() - interval '2 year', now(), now(), '111');

insert into product(idProduct, PrName, PrPrice, InStock, ReOrder, Description)
VALUES(1,'name', -10, 1, '1', '1');

insert into Customers(idCustomer, CompanyName, LastName, FirstName, Address, City, IndexCode, Phone, Email)
VALUES (1, 'name', 'name', 'name', 'adress', 'city', 1, 'phone', 'email');

insert into Customers(idCustomer, CompanyName, LastName, FirstName, Address, City, IndexCode, Phone, Email)
VALUES (2, 'name', 'name', 'name', 'adress', 'city', 1, 'phone', 'email')