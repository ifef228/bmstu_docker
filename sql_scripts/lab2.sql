select * from orders;

select "Customers".companyname, "Customers".lastname from "Customers";

select * from "Customers" order by lastname desc;

select * from items limit 3;

select * from orders
where orderdate > now() - interval '1 week';

select * from product
where  prprice BETWEEN 200 and 700;

select * from orders
where orders.idcustomer in (select "Customers"."idCustomer" from "Customers");

select * from product where prname like '%name1%';

select avg(quantity) from items;

select prname, avg(prprice) as avg from product group by prname
having sum(prprice) = 500;


select "Customers".companyname, orders.shipdate from "Customers"
                                                         join orders on "Customers"."idCustomer" = orders.idcustomer;


select distinct on (status) * from orders;

select EXISTS(values (1, '2025-02-22 09:25:25.595370', '2025-02-22 09:25:25.595370', '2025-02-22 09:25:25.595370', 'nice'));

select product.prname, case
                           when product.instock > 100 then 'more'
                           when instock > 500 then 'good'
                           else '(((('
    end
from product;


select orders.*, "Customers".lastname, "Customers".phone, "Customers".address
from orders join "Customers" on orders.idcustomer = "Customers"."idCustomer"
where orderdate between now() - interval '1 month' and now() order by orderdate asc ;


select "Customers".lastname, "Customers".address, "Customers".phone, "Customers".city, orders.orderdate
from "Customers"
         join orders on "Customers"."idCustomer" = orders.idcustomer
where ("Customers"."idCustomer" = (select idCus from (select "Customers"."idCustomer" as idCus, sum(prprice) as sumprice from "Customers"
                                                                                                                                  join orders on "Customers"."idCustomer" = orders.idcustomer
                                                                                                                                  join items on orders.idorder = items.idorder
                                                                                                                                  join public.product p on items.idproduct = p.idproduct
                                                      group by "Customers"."idCustomer") as table1 where sumprice = (
    select max(sumprice) from (
                                  select sum(prprice) as sumprice from "Customers"
                                                                           join orders on "Customers"."idCustomer" = orders.idcustomer
                                                                           join items on orders.idorder = items.idorder
                                                                           join public.product p on items.idproduct = p.idproduct
                                  group by "Customers"."idCustomer") as table1
)));




