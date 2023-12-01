select * from dim_customer;
select * from dim_product;
select * from fact_forecast_monthly;
select * from fact_sales_monthly;
select * from fact_gross_price;
--------------------------------------------------
select
fm.date,fg.fiscal_year,c.customer_code,
c.customer,c.market,p.product_code,p.product,
p.variant,fm.sold_quantity,fg.gross_price,
round(fm.sold_quantity*fg.gross_price,2) as gross_price_total,
pre.pre_invoice_discount_pct
from dim_customer c left join fact_sales_monthly fm
on c.customer_code=fm.customer_code
join fact_gross_price fg
on fm.product_code=fg.product_code
and get_fiscal_year(fm.date)=fg.fiscal_year
join dim_product p
on p.product_code = fg.product_code
join fact_pre_invoice_deductions pre
on pre.customer_code=c.customer_code and pre.fiscal_year=get_fiscal_year(fm.date)
order by fm.date;

## created a view called 'pre_invoice_discount' using the above query and use it for further analysis
select * from pre_invoce_discount;
## Calculating pre invoice sales and creating a view (pre_invoice_sales) on it
select * ,round((1-pre_invoice_discount_pct)*gross_price_total,2)as pre_invoice_sales 
from pre_invoce_discount;

## include post invoice deduction to calculate net sales
select * from pre_invoice_sales;

## creating a View with the below query ans naming it "post_invoice_discount"
select pre.date,pre.fiscal_year,pre.customer_code,
pre.customer,pre.market,pre.product_code,pre.product,
pre.variant,pre.sold_quantity,pre.gross_price,
round(pre.sold_quantity*pre.gross_price,2) as gross_price_total,
pre.pre_invoice_discount_pct, pre.pre_invoice_sales,
(discounts_pct + other_deductions_pct) as post_invoice_discount_pct
from 
pre_invoice_sales pre 
join fact_post_invoice_deductions post
on pre.customer_code = post.customer_code and
pre.product_code = post.product_code and
pre.fiscal_year = get_fiscal_year(post.date)
order by pre.date;

select * from post_invoice_discount;  ## it is a view
## creating net_sales (using a view and the view name will be 'net_sales')
select * from net_sales;

## Business prob 1: Top 5 market as per Net sales in FY 2020
select market, 
sum(net_sales)/1000000 as total_net_sales_mln
from net_sales
where net_sales.fiscal_year = 2020
group by market
order by total_net_sales_mln desc
limit 5;

## Business prob 2: Top 5 Customers as per Net sales
select customer, 
round(sum(net_sales),2)/1000000 as total_net_sales_mln
from net_sales
group by customer
order by total_net_sales_mln desc
limit 5;

## Business prob 3: Top 5 Products as per Net sales
select products, 
round(sum(net_sales),2)/1000000 as total_net_sales_mln
from net_sales
group by products
order by total_net_sales_mln desc
limit 5;

## Business problem 4: Retrieve the top 2 markets in every region by their gross sales amount in FY=2021.
with cte1 as(
select c.market,c.region,
sum(fm.sold_quantity*fg.gross_price/1000000) as gross_sales_mln
from dim_customer c
left join fact_sales_monthly fm
on c.customer_code = fm.customer_code
join fact_gross_price fg
on fm.product_code = fg.product_code
and get_fiscal_year(fm.date) = fg.fiscal_year
where fg.fiscal_year=2021
group by c.market,c.region),
cte2 as 
(select * ,
rank() over(partition by cte1.region order by cte1.gross_sales_mln desc) as rnk
from cte1)
select * from cte2
where rnk <=2;















