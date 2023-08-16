--simple trend
select date, turnover
from GermanyRetail
where kind_of_trade='Other retail sale of food'
------------------------------------------------------------------
--aggregating at the yearly level
select datepart(year, date) as sales_year, sum(turnover)
from dbo.GermanyRetail
where kind_of_trade='Other retail sale of food'
group by datepart(year, date)
-------------------------------------------------------------------
--Comparing Components
select DATEPART(year, date) as year, kind_of_trade, sum(turnover) as turnover
from GermanyRetail
where kind_of_trade in ('Retail sale of games and toys' ,'Retail sale of sporting equipment', 'Retail sale of books')
group by DATEPART(year, date), kind_of_trade  
order by year
------------------------------------------------------------------------
--Pivoting the data
select datepart(year, date) as sales_year,
		sum(case when kind_of_trade = 'Retail sale of meat and meat products' then turnover  end) as meat_products,
		sum(case when kind_of_trade = 'Retail sale of fruit and vegetables' then turnover end) as fruit_products
from GermanyRetail
group by datepart(year, date)
order by sales_year
 -----------------------------------------------------------------------
 --difference between columns
 select sales_year, round(meat_products - fruit_products, 2) as meat_minus_fruit
 from 
		(select datepart(year, date) as sales_year,
		sum(case when kind_of_trade = 'Retail sale of meat and meat products' then turnover  end) as meat_products,
		sum(case when kind_of_trade = 'Retail sale of fruit and vegetables' then turnover end) as fruit_products
		from GermanyRetail
		where date <= '2022-12-01'
		group by datepart(year, date)
 
		)a
order by sales_year
----------------------------------------------------
--The ratio
select sales_year, round(fruit_products / meat_products,2) as ratio_of_fruit_meat
from 
	(select datepart(year, date) as sales_year,
	 sum(case when kind_of_trade = 'Retail sale of meat and meat products' then turnover end) as meat_products,
	 sum(case when kind_of_trade = 'Retail sale of fruit and vegetables' then turnover end) as fruit_products
	 from GermanyRetail
	 where date <= '2022-12-01'
	 group by datepart(year, date)
	 )a
order by sales_year
------------------------------------------------
--Percent of Total(join)

select date, kind_of_trade, round(turnover * 100 / total_turnover, 2) as pct_total
from
	 (select a.date, a.kind_of_trade, a.turnover, sum(b.turnover) as total_turnover
	  from GermanyRetail a
	  join GermanyRetail b on a.date = b.date and (b.kind_of_trade like '%bread%' or b.kind_of_trade in ('Retail sale of meat and meat products', 'Retail sale of fruit and vegetables'))
	  where a.kind_of_trade like '%bread%' or a.kind_of_trade in ('Retail sale of meat and meat products', 'Retail sale of fruit and vegetables')
	  group by a.date, a.kind_of_trade, a.turnover
	  )aa

--Percent of Total(window function)
SELECT date, kind_of_trade, turnover
,sum(turnover) over (partition by date) as total_turnover
,round(turnover * 100 / sum(turnover) over (partition by date),2) as pct_total
FROM GermanyRetail 
WHERE  kind_of_trade like '%bread%' or kind_of_trade in ('Retail sale of meat and meat products', 'Retail sale of fruit and vegetables')
--------------------------------------------------------
--Percent Change over Time-Indexing time series data
select year_, sales, (FIRST_VALUE(sales) over (order by year_)) as index_, (sales - (FIRST_VALUE(sales) over (order by year_))) as pct_from_index
from
	(
	 select datepart(year, date) as year_, sum(turnover) as sales
	 from GermanyRetail
	 where kind_of_trade = 'Retail sale of clothing'  and date <= '2022-12-01'
	 group by datepart(year, date)
	 ) a

------------------------------------------------------------
--Rolling Time Windows - join
select a.date, a.turnover ,round(avg(b.turnover),2) as moving_avg, count(b.turnover) as count_
from GermanyRetail a
join GermanyRetail b on a.kind_of_trade = b.kind_of_trade  and b.kind_of_trade =  'Retail sale of clothing' and ( b.date between DATEADD(month, -11, a.date) and a.date)
WHERE a.kind_of_trade = 'Retail sale of clothing'
and a.date >= '2010-01-01'
group by a.date, a.turnover
order by date

--Rolling Time Windows -window function
with s as (select date, turnover, round(avg(turnover) over (order by date rows between 11 preceding and current row), 2) as moving_avg,
		count(turnover) over (order by date rows between 11 preceding and current row) as count_
from GermanyRetail
where kind_of_trade = 'Retail sale of clothing' 
)
select *
from s
where date>= '2010-01-01'
---------------------------------------------------
--Rolling window-cumulative value(YTD, QTD)
select date, turnover,
sum(turnover) over (partition by datepart(year, date) order by date) as ytd_sale
from GermanyRetail
where kind_of_trade = 'Retail sale of clothing' 

-------------------------------------QTD
select date, turnover,
sum(turnover) over (partition by datepart(year, date), datepart(quarter, date) order by date) as qtd_sale
from GermanyRetail
where kind_of_trade = 'Retail sale of clothing' 

---join
select a.date, a.turnover, sum(b.turnover) as ytd_sale
from GermanyRetail a join GermanyRetail b on
	datepart(year, a.date) = datepart(year, b.date) and 
	b.date <= a.date and
	b.kind_of_trade = 'Retail sale of clothing'
where a.kind_of_trade = 'Retail sale of clothing'
group by a.date, a.turnover 
order by a.date

----------------------------------------------------
--Period-over-Period Comparisons
select kind_of_trade, date, turnover, lag(date) over (order by date) as pre_date, lag(turnover) over (order by date) as pre_sale
from GermanyRetail
where kind_of_trade = 'Retail sale of watches and jewellery'


select kind_of_trade, date, turnover, round((turnover / lag(turnover) over (order by date) - 1)*100, 2) as pct_groth_prv
from GermanyRetail
where kind_of_trade = 'Retail sale of watches and jewellery'

-------------------------------------YOY
with ss as ( select year(date) as sale_year, sum(turnover) as yearly_sale
			from GermanyRetail
			where kind_of_trade = 'Retail sale of watches and jewellery' and date < '2023-01-01'
			group by year(date))
select sale_year, yearly_sale, round((yearly_sale / lag(yearly_sale) over (order by sale_year) - 1) * 100, 2) as pct_groth_prev
from ss
