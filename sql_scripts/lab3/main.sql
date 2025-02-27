--2
create view expensiveProducts (id, name, price) as (select product.idproduct, product.prname, product.prprice from product where prprice > 500);
select * from expensiveProducts;


--3
select case
           when not exists(
               select *
               from (select expensiveProducts.price, product.prprice  from expensiveProducts
                                                                               join product on product.idproduct = expensiveProducts.id) as pp
               where prprice <> price
           ) then 'по кайфу'
           else 'суши весла'
           end as result;

--4
begin transaction;
alter view expensiveProducts rename column price to fuck;
alter view expensiveProducts rename column fuck to price;
commit;

--5
-- create or replace view expensiveProducts as
--     select product.idproduct, product.prprice from product where prprice < 400;


--6
insert into expensiveProducts(id, name, price) VALUES (11, 'eleven', 1100);


--7
create view cheapProducts(id, name, price) as (select idproduct, prname, prprice from product where prprice < 500)
        with cascaded check option;
--8
drop view cheapProducts;

--9
create view itemsProducts(id, name, quantity) as (select product.idproduct, prname, quantity from product
                                                                                                      join items on product.idproduct = items.idproduct);

--10
create role Test_creator with nologin;
alter role Test_creator createdb;
alter role Test_creator createrole;

--11
create role user1 with login password 'password';
alter role user1 nocreatedb;


--12
grant Test_creator to user1;

--14
create role notable login password 'password';
create role canreadtable login password 'password';

grant SELECT on all tables in schema public to CanReadTable;

--15
grant insert on table product to notable;

--16
revoke insert on table product from notable;
