# Import the Excel file into SQL Server as CovidData.
create database covid_data;
use covid_data;

# Check all rows containing NULL values.
select * from covid_19_data
where ï»¿Province is null
or 'Country/Region' is null
or Latitude is null
or Longitude is null
or Date is null
or Confirmed is null
or Deaths is null
or Recovered is null;

# Replace NULLs in all numeric columns with 0.
set sql_safe_updates = 0;
update covid_19_data
set
latitude =coalesce(latitude,0),
longitude=coalesce(longitude,0),
confirmed=coalesce(confirmed,0),
deaths=coalesce(deaths,0),
recovered=coalesce(recovered,0);

# Display first 10 rows
select * from covid_19_data
limit 10

# Count total number of rows;
select count(*) as total_rows
from covid_19_data;

# Count distinct months per year.
select year(str_to_date(date,'%d-%m-%y')) as year,
count(distinct month(str_to_date(date,'%d-%m-%y'))) as distnict_months
from covid_19_data
group by year(str_to_date(date,'%d-%m-%y'))
order by year;

select date from covid_19_data
limit 10;

#Show start and end date.
select
min(str_to_date(date, '%d-%m-%y')) as start_date,
max(str_to_date(date, '%d-%m-%y')) as end_date
from covid_19_data;

#5. Count rows per year-month.
select
year(str_to_date(date, '%d-%m-%y')) as year,
month(str_to_date(date,'%d-%m-%y')) as month,
count(*) as total_rows
from covid_19_data
group by
year(str_to_date(date,'%d-%m-%y')),
month(str_to_date(date,'%d-%m-%y'))
order by year,month;

#Compute monthly min, max, and total of Confirmed, Deaths, Recovered.
select
year(str_to_date(date,'%d-%m-%y')) as year,
month(str_to_date(date,'%d-%m-%y')) as month,
min(confirmed) as min_confirmed,
max(confirmed) as max_confirmed,
sum(confirmed) as total_confirmed,
min(deaths) as min_deaths,
max(deaths) as max_deaths,
sum(deaths) as total_deaths,
min(recovered) as min_recovered,
max(recovered) as max_recovered,
sum(recovered) as total_recovered
from covid_19_data
group by year(str_to_date(date,'%d-%m-%y')),
month(str_to_date(date,'%d-%m-%y'))
order by year,month;

#CENTRAL TENDENCY
#Compute monthly mean.
select
year(str_to_date(date,'%d-%m-%y')) as year,
month(str_to_date(date,'%d-%m-%y')) as month,
avg(confirmed) as avg_confirmed,
avg(deaths) as avg_deaths,
avg(recovered) as avg_recovered
from covid_19_data
group by year(str_to_date(date,'%d-%m-%y')),
month(str_to_date(date,'%d-%m-%y'))
order by year,month;
# Compute median of Confirmed.
with ordered as (
select
Confirmed,
row_number() over(order by Confirmed) as rn,
count(*) over() as total
from covid_19_data
)
select
Confirmed as median_Confirmed
from ordered
where rn= floor((total+1)/2);

# Compute mode of Confirmed per month.
select m.year,m.month, m.confirmed as mode_confirmed
from ( 
select year(str_to_date(date, '%d-%m-%y')) as year,
month(str_to_date(date, '%d-%m-%y')) as month,
confirmed,
count(*) as freq
from covid_19_data
group by year,month, confirmed
) as m
join ( 
select
year,
month,
max(freq) as max_freq
from (
select
year(str_to_date(date,'%d-%m-%y')) as year,
month(str_to_date(date,'%d-%m-%y')) as month,
confirmed,
count(*) as freq
from covid_19_data
group by year,month, confirmed
) as x
group by year,month) as mx
on m.year=mx.year
and m.month=mx.month
and m.freq=mx.max_freq
order by m.year, m.month;

# Compute total, average, variance, std deviation for Confirmed, Deaths, Recovered (overall & by month-year)
select
year(str_to_date(date, '%d-%m-%y')) as year,
month(str_to_date(date, '%d-%m-%y')) as month,
sum(confirmed) as total_confirmed,
avg(confirmed) as avg_confirmed,
variance(confirmed) as var_confirmed,
stddev(confirmed) as std_confirmed,

sum(deaths) as total_deaths,
avg(deaths) as avg_deaths,
variance(deaths) as var_deaths,
stddev(deaths) as std_deaths,

sum(recovered) as total_recovered,
avg(recovered) as avg_recovered,
variance(recovered) as var_recovered,
stddev(recovered) as std_recovered
from covid_19_data
group by year,month
order by year,month;

# Compute 50th, 60th, 90th, 95th percentiles using PERCENTILE_DISC or PERCENTILE_CONT.
with ordered as (
select
confirmed,
row_number() over (order by confirmed) as rn,
count(*) over () as total
from covid_19_data
)
select
(
select confirmed from ordered
where rn= floor(total*0.50)
) as p50_confirmed,
(
select confirmed from ordered
where rn= floor(total*0.60)
) as p60_confirmed,
(
select confirmed from ordered
where rn= floor(total*0.90)
) as p90_confirmed,
(
select confirmed from ordered
where rn= floor(total*0.95)
) as p95_confirmed;

# Top 10 highest Confirmed, Deaths, Recovered.
select *
from covid_19_data
order by confirmed desc, deaths desc, recovered desc
limit 10;

# correlation: confirmed vs deaths
select
(sum(Confirmed*Deaths)-sum(Confirmed)*sum(Deaths)/count(*))/
sqrt((sum(Confirmed*Confirmed)- sum(Confirmed)*sum(Confirmed)/count(*))*
	(sum(deaths*Deaths)-sum(Deaths)*sum(Deaths)/count(*))) as corr_Confirmed_Deaths,
#correlation: confirmed vs recovered
(sum(Confirmed*Recovered)-sum(Confirmed)*sum(Recovered)/count(*))/
(sqrt(sum(Confirmed*Confirmed)-sum(Confirmed)*sum(Confirmed)/count(*))*
(sum(Recovered*Recovered)- sum(Recovered)*sum(Recovered)/count(*))) as corr_Confirmed_Recovered,
#correlation: deaths vs recovered
(sum(Deaths*Recovered)- sum(Deaths)*sum(Recovered)/count(*))/
(sqrt(sum(Deaths*Deaths)- sum(Deaths)*sum(Deaths)/count(*))*
(sum(Recovered*Recovered)-sum(Recovered)*sum(Recovered)/count(*))) as corr_Deaths_Recovered
from covid_19_data;

# Use ROW_NUMBER() to rank by Confirmed cases.
select
Date,
Confirmed,
Deaths,
Recovered,
row_number() over(order by Confirmed desc) as rank_confirmed
from covid_19_data
order by rank_confirmed;

# REGRESSION MODEL
#Compute slope and intercept where:
#x = Confirmed
#y = Deaths
#Write regression equation y = mx + b and interpret it
#slope (m)
select
(count(*)*sum(Confirmed*Deaths)-sum(Confirmed)*sum(Deaths))/
(count(*)*sum(Confirmed*Confirmed)-sum(Confirmed)*sum(Confirmed)) as slope,
# intercept (b)
(sum(Deaths)-
((count(*)*sum(Confirmed*Deaths)-sum(Confirmed)*sum(Deaths))/
(count(*)*sum(Confirmed*Confirmed)-sum(Confirmed)*sum(Confirmed)))
*sum(Confirmed)
)/count(*) as intercept
from covid_19_data;