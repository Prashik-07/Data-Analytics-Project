INSERT INTO stores_cleaned (store_id, store_name, store_type, region, city, operating_cost)
VALUES ('ONLINE_STORE', 'Online Store', 'E-commerce', 'National', 'Online', 0);

---Index---
---Sales---

CREATE INDEX customers_index
ON salesdata_cleaned(customer_id);

CREATE INDEX salesdata_index
ON salesdata_cleaned(store_id);

CREATE INDEX products_index
ON salesdata_cleaned(product_id);

CREATE INDEX stores_index
ON salesdata_cleaned(order_date);

---Products---

CREATE INDEX IDX_product_category
ON products_cleaned(category);

---Customers---

CREATE INDEX IDX_customer_region
ON customers_cleaned(region);

---Returns---

CREATE INDEX IDX_return_order_id
ON returns_cleaned(order_id);

CREATE INDEX IDX_return_date
ON returns_cleaned(return_date);

---Stores---

CREATE INDEX IDX_region
ON stores_cleaned(region);


-----Derived Metrics-----

---Profit Per Order---
SELECT
	s.order_id,
	(s.total_amount - (p.cost_price * s.quantity)) AS profit_per_order
FROM salesdata_cleaned s
	INNER JOIN products_cleaned p
ON s.product_id = p.product_id;

---Total Profit---
SELECT ROUND(SUM(profit),2) AS Total_Profit
FROM salesdata_cleaned

---Category Wise Profit---
SELECT
	p.category,
	ROUND(SUM(s.total_amount - (p.cost_price * s.quantity)),2) AS category_profit
FROM salesdata_cleaned s
	INNER JOIN products_cleaned p
ON s.product_id = p.product_id
GROUP BY p.category;

---Discount Percentage---
SELECT
	ROUND(((SUM(discount_pct * total_amount)/SUM(total_amount) * 100)),2) AS Discount_Percentage
FROM salesdata_cleaned

---Return Rate---
SELECT
	ROUND(CAST(COUNT(r.return_id)*100.0/COUNT(s.order_id) AS FLOAT),2) AS Return_rate
FROM salesdata_cleaned s
	LEFT JOIN returns_cleaned r
ON s.order_id = r.order_id


---------- Business Questions ----------

-- 1. What is the total revenue generated in the last 12 months?
SELECT ROUND(SUM(total_amount),2) AS Total_Revenue_Last_12months
FROM salesdata_cleaned
WHERE order_date >= DATEADD(month,-12,(SELECT MAX(order_date) FROM salesdata_cleaned))
-- 516437.93

-- 2. Which are the top 5 best-selling products by quantity?
SELECT
	TOP 5 p.product_name, SUM(CAST(s.quantity AS INT)) AS Total_Quantity
FROM products_cleaned p
INNER JOIN salesdata_cleaned s
ON p.product_id = s.product_id
GROUP BY p.product_name
ORDER BY SUM(CAST(s.quantity AS INT)) desc;

-- 3. How many customers are from each region?
SELECT
	region, count(*) AS customer_count
FROM customers_cleaned
GROUP BY region
ORDER BY customer_count DESC;

-- 4. Which store has the highest profit in the past year?
SELECT
	TOP 1 sb.store_name, ROUND(SUM(sa.profit), 2) AS Total_Profit
FROM salesdata_cleaned sa
	JOIN stores_cleaned sb
ON sa.store_id = sb.store_id
WHERE sa.order_date >= DATEADD(YEAR, -1, GETDATE())
GROUP BY sb.store_name
ORDER BY Total_Profit DESC;

-- 5. What is the return rate by product category?
SELECT p.category, ROUND(CAST(COUNT(r.return_id)*100.0/COUNT(s.order_id) AS FLOAT),2) AS Return_rate_product_category
FROM salesdata_cleaned s
INNER JOIN products_cleaned p
ON s.product_id = p.product_id
LEFT JOIN returns_cleaned r
ON s.order_id = r.order_id
GROUP BY p.category

-- 6. What is the average revenue per customer by age group?
SELECT
	c.Age_Group,
	ROUND(AVG(s.total_amount),2) AS AVG_revenue_per_customer
FROM salesdata_cleaned s
	INNER JOIN customers_cleaned c
ON s.customer_id = c.customer_id
GROUP BY c.age_group
ORDER BY c.age_group

-- 7. Which sales channel (Online vs In-Store) is more profitable on avergae?
SELECT
	sales_channel,
	ROUND(AVG(profit),2) AS AVG_profit_Online_Instores
FROM salesdata_cleaned sa
GROUP BY sales_channel
ORDER BY AVG_profit_Online_Instores DESC;

-- 8. How has monthly profit changed over the last 2 years by region?
SELECT
	sb.region,
	year(sa.order_date) AS SALES_YEAR,
	month(sa.order_date) AS SALES_MONTH,
	ROUND(SUM(sa.profit),2) AS monthly_profit
FROM salesdata_cleaned sa
	INNER JOIN stores_cleaned sb
ON sa.store_id = sb.store_id
WHERE sa.order_date >= DATEADD(year, -2,(SELECT MAX(order_date) FROM salesdata_cleaned)) AND sb.region <> '-'
GROUP BY sb.region, year(sa.order_date), month(sa.order_date)
ORDER BY Sales_Month, sb.region, sales_year;

-- 9. Identify the top 3 products with the highest return rate in each category?
SELECT Product_Name, Category, Return_Rate
FROM(
	SELECT
			p.product_name AS Product_Name,
			p.category AS Category,
			ROUND(CAST(COUNT(r.return_id)*100/COUNT(s.order_id) AS FLOAT),2) AS Return_Rate,
			ROW_NUMBER()over(PARTITION BY p.category ORDER BY COUNT(r.return_id)*100/COUNT(s.order_id) DESC) AS RANK
	FROM products_cleaned p
		LEFT JOIN salesdata_cleaned s
	ON p.product_id = s.product_id
		INNER JOIN returns_cleaned r
	ON r.order_id = s.order_id
	GROUP BY p.product_name, p.category
) t
WHERE RANK <= 3;

-- 10. Which 5 customers have contributed the most to total profit, and what is their tenure with the company?
SELECT
	TOP 5 CONCAT(c.first_name,' ',c.last_name) AS Customer_Name,
	ROUND(SUM(s.profit),2) AS Total_Profit,
	CAST(DATEDIFF(MONTH, c.signup_date, (SELECT MAX(order_date) FROM salesdata_cleaned)) AS VARCHAR(255))+' Months' AS "Tenure (in months)"
FROM customers_cleaned c
	JOIN salesdata_cleaned s
ON c.customer_id = s.customer_id
GROUP BY
	CONCAT(c.first_name,' ',c.last_name),
	c.signup_date
ORDER BY Total_Profit desc;


