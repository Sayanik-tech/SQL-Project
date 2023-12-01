select * from dim_customer;
select * from dim_product;
select * from fact_forecast_monthly;
select * from fact_sales_monthly;
select * from fact_gross_price;
--------------------------------------------
## forecast accuracy
## Business Problem 1: I need an aggregate forecast accuracy report for all the customers for a given fiscal year.
##                   so that I can track the accuracy of the forecast we make for the customers
## Columns: Customer_code,Name,Market,Total sold Quantity,Total forecast quantity,
##	        Net error,Absolute error,Forecast accuract %

drop table if exists fact_act_est;
create table fact_act_est      ## temporary table
	(
        	select 
                    s.date as date,
                    get_fiscal_year(s.date) as fiscal_year,
                    s.product_code as product_code,
                    s.customer_code as customer_code,
                    s.sold_quantity as sold_quantity,
                    f.forecast_quantity as forecast_quantity
        	from 
                    fact_sales_monthly s
        	left join fact_forecast_monthly f 
        	using (date, customer_code, product_code)
	)
	union
	(
        	select 
                    f.date as date,
                    f.fiscal_year as fiscal_year,
                    f.product_code as product_code,
                    f.customer_code as customer_code,
                    s.sold_quantity as sold_quantity,
                    f.forecast_quantity as forecast_quantity    
        	from 
		    fact_forecast_monthly  f
        	left join fact_sales_monthly s 
        	using (date, customer_code, product_code)
	);

	update fact_act_est
	set sold_quantity = 0
	where sold_quantity is null;

	update fact_act_est
	set forecast_quantity = 0
	where forecast_quantity is null;
    
## Using CTE to create a forecast accuracy report and it will be stored at stored procedure for further use
	
    create temporary table forecast_err_table
		select
                  s.customer_code as customer_code,
                  sum(s.sold_quantity) as total_sold_qty,
                  sum(s.forecast_quantity) as total_forecast_qty,
                  sum(s.forecast_quantity-s.sold_quantity) as net_error,
                  round(sum(s.forecast_quantity-s.sold_quantity)*100/sum(s.forecast_quantity),1) as net_error_pct,
                  sum(abs(s.forecast_quantity-s.sold_quantity)) as abs_error,
                  round(sum(abs(s.forecast_quantity-sold_quantity))*100/sum(s.forecast_quantity),2) as abs_error_pct
             from fact_act_est s
             join dim_customer c
             on s.customer_code = c.customer_code
             where s.fiscal_year=2021
             group by customer_code;
	select 
	ft.*,
    c.customer as customer_name,
	c.market as market,
	if (abs_error_pct > 100, 0, 100.0 - abs_error_pct) as forecast_accuracy
	from forecast_err_table ft join dim_customer c
	order by ft.forecast_accuracy desc;
    
## Business problem 2: The supply chain business manager wants to see which customers’ forecast accuracy has dropped from 2020 to 2021. 
 ##   Provide a complete report with these columns: customer_code, customer_name, market, forecast_accuracy_2020, forecast_accuracy_2021

with cte1 as 
( select
                  s.customer_code as customer_code,
                  sum(s.sold_quantity) as total_sold_qty,
                  sum(s.forecast_quantity) as total_forecast_qty,
                  sum(s.forecast_quantity-s.sold_quantity) as net_error,
                  round(sum(s.forecast_quantity-s.sold_quantity)*100/sum(s.forecast_quantity),1) as net_error_pct,
                  sum(abs(s.forecast_quantity-s.sold_quantity)) as abs_error,
                  round(sum(abs(s.forecast_quantity-sold_quantity))*100/sum(s.forecast_quantity),2) as abs_error_pct
             from fact_act_est s
             where s.fiscal_year=2020
             group by customer_code
             order by customer_code),
	cte2 as 
    (
    select cte1.*,
	c.customer,
    c.market,
    if (cte1.abs_error_pct > 100, 0, 100.0 - cte1.abs_error_pct) as forecast_accuracy_2020
    from cte1  join dim_customer c
    on cte1.customer_code=c.customer_code
    order by forecast_accuracy_2020 desc
    ),
    cte3 as 
    (
    select
                  s.customer_code as customer_code,
                  sum(s.sold_quantity) as total_sold_qty,
                  sum(s.forecast_quantity) as total_forecast_qty,
                  sum(s.forecast_quantity-s.sold_quantity) as net_error,
                  round(sum(s.forecast_quantity-s.sold_quantity)*100/sum(s.forecast_quantity),1) as net_error_pct,
                  sum(abs(s.forecast_quantity-s.sold_quantity)) as abs_error,
                  round(sum(abs(s.forecast_quantity-sold_quantity))*100/sum(s.forecast_quantity),2) as abs_error_pct
             from fact_act_est s
             where s.fiscal_year=2021
             group by customer_code
             order by customer_code
    ),
    cte4 as 
    (
    select cte3.*,
	c.customer,
    c.market,
    if (cte3.abs_error_pct > 100, 0, 100.0 - cte3.abs_error_pct) as forecast_accuracy_2021
    from cte3  join dim_customer c
    on cte3.customer_code=c.customer_code
    order by forecast_accuracy_2021 desc
    )
    select cte2.customer_code,
        cte2.customer,
	    cte2.market,
        forecast_accuracy_2020,
        forecast_accuracy_2021
        from cte2 join cte4
        on cte2.customer_code = cte4.customer_code
        where forecast_accuracy_2021<forecast_accuracy_2020;
    
    




