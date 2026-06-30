-- retail performance & operations deep-dive
-- postgres production replica
-- quick cleanup script for checking power bi numbers + starting the management report

-- q1: dynamic sanity check on KPIs to verify power bi model matches base tables
SELECT 
    sum(sales) AS total_gross_sales,
    sum(profit) AS total_net_profit,
    sum(quantity) AS total_items_moved,
    count(distinct order_id) AS total_order_volume,
    round((sum(profit) / sum(sales) * 100)::num, 2) AS corporate_net_margin  
FROM global_orders;


-- q2: bleeding skus. finding out which lines are leaking the most cash
-- sorting asc to drop the heaviest losses straight into row 1
SELECT 
    product_name,
    category,
    sub_category,
    sum(sales) AS item_revenue,
    sum(profit) AS total_net_loss
FROM global_orders
GROUP BY 1, 2, 3  
HAVING sum(profit) < 0
ORDER BY total_net_loss asc 
LIMIT 5;


-- q3: the markdown trap. checking if aggressive promos are killing specific sub-cat margins
-- filtering for heavy discounts (>15%) to spot where pricing strategies backfired
select 
    sub_category,
    count(*) as heavy_discount_tx_count,
    round(avg(discount * 100)::num, 1) as mean_discount_percentage,
    sum(sales) as total_sales_volume,
    sum(profit) as net_profit_outcome
from global_orders
where discount > 0.15
group by sub_category
order by net_profit_outcome asc;


-- q4: regional contribution matrix (sorting by net yield to spot cash cows)
select 
    market,
    region,
    sum(sales) as gross_revenue,
    sum(profit) as net_yield,
    round((sum(profit)/sum(sales)*100)::num, 2) as regional_margin_pct
from global_orders
group by market, region
order by net_yield desc;


-- q5: fulfillment drag. calculating lag between ordering and shipping across methods
-- dropping null dates to keep averages clean
SELECT 
    ship_mode,
    count(order_id) as shipment_count,
    round(avg(ship_date - order_date)::num, 2) as avg_days_to_ship,
    sum(profit) as mode_profitability
FROM global_orders
where order_date is not null and ship_date is not null
GROUP BY ship_mode
ORDER BY avg_days_to_ship ASC;


-- q6: top 1% power buyers (clv blueprint for marketing targets)
SELECT 
    customer_id,
    customer_name,
    segment,
    count(distinct order_id) as order_frequency,
    sum(sales) as life_time_spend,
    sum(profit) as client_net_profit
FROM global_orders
GROUP BY customer_id, customer_name, segment
ORDER BY client_net_profit DESC
LIMIT 10;


-- q7: sla violations. flagging warehouse bottlenecks taking > 5 days to clear gates
SELECT 
    order_id,
    customer_name,
    market,
    (ship_date - order_date) as shipping_delay_days,
    sales,
    profit
FROM global_orders
where (ship_date - order_date) > 5
order by shipping_delay_days desc
limit 15;


-- q8: high-level inventory performance 
SELECT 
    category,
    sum(quantity) as units_shipped,
    sum(sales) as categorical_revenue,
    sum(profit) as categorical_profit,
    round((sum(profit)/sum(sales)*100)::num, 2) as efficiency_ratio
FROM global_orders
GROUP BY category
ORDER BY categorical_profit DESC;


-- q9: seasonal growth vectors (provides the raw numbers for the forecasting page)
SELECT 
    extract(year from order_date) as op_year,
    extract(month from order_date) as op_month,
    sum(sales) as monthly_gross,
    sum(profit) as monthly_net,
    count(distinct order_id) as order_velocity
FROM global_orders
group by 1, 2
order by op_year desc, op_month desc;
