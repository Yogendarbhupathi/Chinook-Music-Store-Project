-- Objective Questions

USE chinook;
-- 1. Does any table have missing values or duplicates? If yes how would you handle it ?

-- checking for null values
SELECT * FROM album; -- No null Values
SELECT * FROM artist; -- No null Values
SELECT * FROM customer; -- company, state, postal_code, phone, fax columns contain null values
SELECT * FROM employee; -- No null Values
SELECT * FROM genre; -- No null Values
SELECT * FROM invoice; -- No null Values
SELECT * FROM invoice_line; -- No null Values
SELECT * FROM media_type; -- No null Values
SELECT * FROM playlist; -- No null Values
SELECT * FROM playlist_track; -- No null Values
SELECT * FROM track; -- composer column contains null values

-- Replacing null values
UPDATE customer SET company = "Unknown"
WHERE company IS NULL; -- 49 rows effected
UPDATE customer SET state = "Unknown"
WHERE state IS NULL; -- 29 rows effected
UPDATE customer SET postal_code = "Unknown"
WHERE postal_code IS NULL; -- 4 rows effected
UPDATE customer SET phone = "+0 000 000-0000"
WHERE phone IS NULL; -- 1 rows effected
UPDATE customer SET fax = "+0 000 000-0000"
WHERE fax IS NULL; -- 47 rows effected
UPDATE track SET composer = 'Unknown' 
WHERE composer IS NULL; -- 978 row(s) affected

-- NO duplicate values in all the tables

-- 2. Find the top-selling tracks and top artist in the USA and identify their most famous genres.
SELECT
t.name AS track_name,
ar.name AS artist_name,
g.name as genre_name,
SUM(i.total) total_revenue,
COUNT(t.track_id) AS total_purchases
FROM invoice i
JOIN invoice_line il ON i.invoice_id = il.invoice_id
JOIN track t ON il.track_id = t.track_id
JOIN album al ON t.album_id = al.album_id
JOIN artist ar ON al.artist_id = ar.artist_id
JOIN genre g ON t.genre_id = g.genre_id
WHERE i.billing_country = "USA"
GROUP BY t.name, ar.name, g.name
ORDER BY total_revenue DESC
LIMIT 10;

-- 3. What is the customer demographic breakdown (age, gender, location) of Chinook's customer base?
SELECT
country,
state,
city,
COUNT(*) AS customer_count
FROM customer
GROUP BY country, state, city
ORDER BY country, state, city;

-- 4. Calculate the total revenue and number of invoices for each country, state, and city:
SELECT
billing_country,
billing_state,
billing_city,
SUM(total) AS total_revenue,
COUNT(invoice_id) AS total_invoices
FROM invoice
GROUP BY billing_country, billing_state, billing_city
ORDER BY billing_country, total_revenue DESC;

-- 5. Find the top 5 customers by total revenue in each country
WITH cus_data AS (
	SELECT
	c.customer_id, 
	c.first_name, 
	c.last_name, 
	c.country,
	SUM(il.unit_price * il.quantity) AS total_revenue,
    RANK() OVER(PARTITION BY c.country ORDER BY SUM(il.unit_price * il.quantity) DESC) AS rnk
	FROM invoice i
	JOIN customer c ON i.customer_id = c.customer_id
	GROUP BY c.customer_id, c.first_name, c.last_name, c.country
)

SELECT
customer_id, 
first_name, 
last_name, 
country,
total_revenue
FROM cus_data
WHERE rnk <= 5
ORDER BY country, total_revenue DESC;

-- 6. Identify the top-selling track for each customer
WITH cus_data AS (
	SELECT
	c.customer_id, 
	CONCAT(c.first_name, " ", c.last_name) AS customer_full_name,
    t.track_id,
    t.name AS track_name,
    COUNT(il.quantity) AS total_tracks_sold,
    SUM(i.total) AS total_cost,
    RANK() OVER(PARTITION BY c.customer_id ORDER BY COUNT(il.quantity) DESC, SUM(i.total) DESC) AS rnk
	FROM customer c
	JOIN invoice i ON c.customer_id = i.customer_id
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t ON il.track_id = t.track_id
    GROUP BY c.customer_id, c.first_name, c.last_name, t.track_id, t.name
)

SELECT *
FROM cus_data
WHERE rnk = 1
ORDER BY total_tracks_sold DESC, customer_id;

-- 7. Are there any patterns or trends in customer purchasing behavior (e.g., frequency of purchases, preferred payment methods, average order value)?
SELECT
	c.customer_id, 
	CONCAT(c.first_name, " ", c.last_name) AS customer_name,
	MIN(DATE(invoice_date)) AS first_purchase,
	MAX(DATE(invoice_date)) AS lastest_purchase,
	ROUND(
		DATEDIFF(MAX(invoice_date), MIN(invoice_date))
		/
		COUNT(i.invoice_id) - 1
	, 0) as avg_days,
    COUNT(i.invoice_id) AS total_purchases,
    SUM(i.total) AS total_purchase_amount,
    ROUND(AVG(i.total), 2) AS avg_purchase_amount
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY customer_id;

-- 8. What is the customer churn rate?
-- Finding the latest purchase for reference
SELECT MAX(invoice_date)
FROM invoice;

-- 8. Finding customer chunk rate
WITH filter_data AS (
	SELECT
		DISTINCT customer_id
	FROM invoice
    WHERE invoice_date >= '2020-12-30' - INTERVAL 6 MONTH
),
chunk_customers AS (
	SELECT
		customer_id
	FROM customer
    WHERE customer_id NOT IN (SELECT customer_id FROM filter_data)
)

SELECT
	(SELECT COUNT(DISTINCT customer_id) FROM invoice) AS total_customers,
    (SELECT COUNT(*) FROM chunk_customers) AS total_chunk_customers,
    ROUND(
		((SELECT COUNT(*) FROM chunk_customers) * 100)
        /
        (SELECT COUNT(DISTINCT customer_id) FROM invoice)
    , 2) AS customer_chunk_rate
    
-- 9. Calculate the percentage of total sales contributed by each genre in the USA and identify the best-selling genres and artists.
-- 9.1 Finding percentage of total sales contributed by each genre in the USA
WITH genre_sales AS (
	SELECT
		g.name AS genre_name,
        sum(il.unit_price * il.quantity) AS revenue
	FROM invoice i
	JOIN invoice_line il ON i.invoice_id = il.invoice_id
	JOIN track t ON il.track_id = t.track_id
	JOIN genre g ON t.genre_id = g.genre_id
    WHERE i.billing_country = "USA"
    GROUP BY g.name
),
total_sales AS (
	SELECT
		sum(il.unit_price * il.quantity) AS total_revenue
	FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    WHERE billing_country = "USA"
)

SELECT
	genre_name,
    ROUND( revenue * 100 / (SELECT total_revenue FROM total_sales), 2) AS percentage_sales
FROM genre_sales
ORDER BY percentage_sales DESC;

-- 9.2 Best selling genres and artists in USA
SELECT
	ar.name AS artist_name,
	g.name as genre_name,
	SUM(il.unit_price * il.quantity) total_revenue
FROM invoice i
JOIN invoice_line il ON i.invoice_id = il.invoice_id
JOIN track t ON il.track_id = t.track_id
JOIN album al ON t.album_id = al.album_id
JOIN artist ar ON al.artist_id = ar.artist_id
JOIN genre g ON t.genre_id = g.genre_id
WHERE i.billing_country = "USA"
GROUP BY ar.name, g.name
ORDER BY total_revenue DESC
LIMIT 5;

-- 10. Find customers who have purchased tracks from at least 3 different genres
SELECT
	c.customer_id,
    CONCAT(c.first_name, " ", c.last_name) AS customer_name,
    COUNT(DISTINCT t.genre_id) AS different_genres_purchased
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
JOIN invoice_line il ON i.invoice_id = il.invoice_id
JOIN track t ON il.track_id = t.track_id
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING COUNT(DISTINCT t.genre_id) >= 3
ORDER BY different_genres_purchased DESC, c.customer_id;

-- 11. Rank genres based on their sales performance in the USA
SELECT
	g.genre_id,
    g.name AS genre_name,
    SUM(il.quantity * il.unit_price) AS total_sales,
    RANK() OVER(ORDER BY SUM(il.quantity * il.unit_price) DESC) AS genre_rank
FROM invoice i
JOIN invoice_line il ON i.invoice_id = il.invoice_id
JOIN track t ON il.track_id = t.track_id
JOIN genre g ON t.genre_id = g.genre_id
WHERE i.billing_country = "USA"
GROUP BY g.genre_id, g.name
ORDER BY genre_rank;

-- 12. Identify customers who have not made a purchase in the last 3 months
-- Finding latest sales date
SELECT 
	MAX(invoice_date) as latest_sales_date
FROM invoice;
-- '2020-12-30'

-- To find customers who have not made a purchase in the last 3 months
WITH cus_data AS (
	SELECT
		DISTINCT customer_id
	FROM invoice
	WHERE invoice_date >= '2020-12-30' - INTERVAL 3 MONTH
)

SELECT
	c.customer_id,
	CONCAT(c.first_name, " ", c.last_name) AS customer_name,
	MAX(DATE(i.invoice_date)) AS last_purchase_date
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
WHERE c.customer_id NOT IN (SELECT customer_id FROM cus_data)
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY c.customer_id;


-- Subjective Questions

-- 1.Recommend the three albums from the new record label that should be prioritised for advertising and promotion in the USA based on genre sales analysis.
SELECT
	al.album_id,
	al.title AS album_title,
	ar.name AS artist_name,
	g.name AS genre_name,
	SUM(il.unit_price * il.quantity) AS total_sales
FROM invoice i
JOIN invoice_line il ON i.invoice_id = il.invoice_id
JOIN track t ON il.track_id = t.track_id
JOIN genre g ON t.genre_id = g.genre_id
JOIN album al ON t.album_id = al.album_id
JOIN artist ar ON al.artist_id = ar.artist_id
WHERE i.billing_country = "USA"
GROUP BY al.album_id, al.title, ar.name, g.name
ORDER BY total_sales DESC, genre_name
LIMIT 5;

-- 2. Determine the top-selling genres in countries other than the USA and identify any commonalities or differences.
SELECT
	g.genre_id,
	g.name AS genre_name,
	SUM(il.unit_price * il.quantity) AS total_sales
FROM invoice i
JOIN invoice_line il ON i.invoice_id = il.invoice_id
JOIN track t ON il.track_id = t.track_id
JOIN genre g ON t.genre_id = g.genre_id
WHERE i.billing_country != "USA"
GROUP BY g.genre_id, g.name
ORDER BY total_sales DESC, genre_name
LIMIT 5;

-- 3. Customer Purchasing Behavior Analysis: How do the purchasing habits (frequency, basket size, spending amount) of long-term customers differ from those of new customers? 
-- What insights can these patterns provide about customer loyalty and retention strategies?
WITH cus_data AS (
    SELECT
        CASE 
            WHEN YEAR(invoice_date) <= 2019 THEN 'Long-Term'
            ELSE 'New'
        END AS customer_category,
        COUNT(DISTINCT i.invoice_id) AS purchase_frequency,
        SUM(il.quantity) / COUNT(DISTINCT i.invoice_id) AS avg_basket_size,
        SUM(i.total) AS total_amount
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    GROUP BY customer_category
)

SELECT 
    customer_category,
    ROUND(AVG(purchase_frequency), 2) AS avg_purchase_frequency,
    ROUND(AVG(avg_basket_size), 2) AS avg_basket_size,
    ROUND(AVG(total_amount), 2) AS avg_total_amount
FROM cus_data
GROUP BY customer_category;

-- 4. Product Affinity Analysis: Which music genres, artists, or albums are frequently purchased together by customers? 
-- How can this information guide product recommendations and cross-selling initiatives?
-- Genre Affinity
WITH genre_data AS (
	SELECT
		i.invoice_id,
        g.name
	FROM invoice i
	JOIN invoice_line il ON i.invoice_id = il.invoice_id
	JOIN track t ON il.track_id = t.track_id
	JOIN genre g ON t.genre_id = g.genre_id
)

SELECT
	g1.name AS genre_1,
    g2.name AS genre_2,
    COUNT(*) AS genre_frequent_purchases
FROM genre_data g1
JOIN genre_data g2 ON g1.invoice_id = g2.invoice_id AND g1.name < g2.name
GROUP BY g1.name, g2.name
ORDER BY genre_frequent_purchases DESC
LIMIT 5;

-- Artist Affinity
WITH artist_data AS (
	SELECT
		i.invoice_id,
        ar.name
	FROM invoice i
	JOIN invoice_line il ON i.invoice_id = il.invoice_id
	JOIN track t ON il.track_id = t.track_id
	JOIN album al ON t.album_id = al.album_id
    JOIN artist ar ON al.artist_id = ar.artist_id
)

SELECT
	ar1.name AS artist_1,
    ar2.name AS artist_2,
    COUNT(*) AS artist_frequent_purchases
FROM artist_data ar1
JOIN artist_data ar2 ON ar1.invoice_id = ar2.invoice_id AND ar1.name < ar2.name
GROUP BY ar1.name, ar2.name
ORDER BY artist_frequent_purchases DESC
LIMIT 5;

-- Album Affinity
WITH album_data AS (
	SELECT
		i.invoice_id,
        al.title
	FROM invoice i
	JOIN invoice_line il ON i.invoice_id = il.invoice_id
	JOIN track t ON il.track_id = t.track_id
	JOIN album al ON t.album_id = al.album_id
)

SELECT
	al1.title AS album_1,
    al2.title AS album_2,
    COUNT(*) AS album_frequent_purchases
FROM album_data al1
JOIN album_data al2 ON al1.invoice_id = al2.invoice_id AND al1.title < al2.title
GROUP BY al1.title, al2.title
ORDER BY album_frequent_purchases DESC
LIMIT 5;

-- 5. Regional Market Analysis: Do customer purchasing behaviors and churn rates vary across different geographic regions or store locations? 
-- How might these correlate with local demographic or economic factors?
WITH latest_sales AS (
	SELECT 
		customer_id,
		MAX(invoice_date) AS latest_purchase
	FROM invoice
    GROUP BY customer_id
),
churn_data AS (
	SELECT
		customer_id,
        latest_purchase,
        CASE
			WHEN latest_purchase < '2020-12-30' - INTERVAL 3 MONTH THEN "churned_user"
            ELSE "Active_user"
		END as customer_category
	FROM latest_sales
),
country_data AS (
	SELECT
		billing_country AS country,
        COUNT(DISTINCT customer_id) AS total_customers,
        SUM(total) AS revenue,
        AVG(total) AS avg_order_amount,
        COUNT(invoice_id) AS total_orders
	FROM invoice
    GROUP BY billing_country
),
chunk_calculations AS (
	SELECT
		i.billing_country AS country,
        c.customer_category,
        COUNT(DISTINCT c.customer_id) AS total_customers
	FROM invoice i
	JOIN churn_data c ON i.customer_id = c.customer_id AND c.customer_category = "churned_user"
	GROUP BY country, c.customer_category
)

SELECT
	cd.country,
    cd.revenue,
    cd.avg_order_amount,
    cd.total_orders,
    cd.total_customers,
    ROUND(
		COALESCE(CASE WHEN cc.customer_category = "churned_user" THEN cc.total_customers END, 0) * 100
        /
        cd.total_customers
    , 2) AS churn_percentage
FROM country_data cd
LEFT JOIN chunk_calculations cc ON cd.country = cc.country
ORDER BY cd.country;

-- 6. Customer Risk Profiling: Based on customer profiles (age, gender, location, purchase history), which customer segments are more likely to churn or pose a higher risk of reduced spending? What factors contribute to this risk?
WITH cus_data AS (
	SELECT
		DISTINCT customer_id,
        COUNT(*) AS total_latest_orders
	FROM invoice 
    WHERE invoice_date > '2020-12-30' - INTERVAL 1 YEAR
	GROUP BY customer_id
),
summary AS (
	SELECT
		customer_id,
        billing_country AS country,
        SUM(total) AS total_spent,
        COUNT(*) AS total_orders,
        AVG(total) AS avg_order_amount
	FROM invoice
    GROUP BY customer_id, billing_country
)

SELECT
	s.*,
    CASE
		WHEN c.total_latest_orders < 2 OR s.total_orders < 5 OR s.total_spent < 20 THEN "High Risk"
		ELSE "Low Risk"
	END customer_status
FROM summary s
JOIN cus_data c ON s.customer_id = c.customer_id
ORDER BY customer_status, s.customer_id;

-- 7. Customer Lifetime Value Modeling: How can you leverage customer data (tenure, purchase history, engagement) to predict the lifetime value of different customer segments? 
-- This could inform targeted marketing and loyalty program strategies. Can you observe any common characteristics or purchase patterns among customers who have stopped purchasing?
SELECT
	c.customer_id,
    CONCAT(c.first_name, " ", c.last_name) AS customer_full_name,
    MIN(DATE(i.invoice_date)) AS first_purchase,
	MAX(DATE(i.invoice_date)) AS latest_purchase,
    DATEDIFF(MAX(DATE(i.invoice_date)), MIN(DATE(i.invoice_date))) AS tenure,
    SUM(i.total) AS total_spent,
    COUNT(i.invoice_id) AS total_orders,
    ROUND(AVG(i.total), 2) AS avg_order_amount,
    CASE
		WHEN MAX(DATE(i.invoice_date)) < '2020-12-30' - INTERVAL 6 MONTH THEN "churned customer"
        ELSE "Active customer"
	END AS customer_category
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.customer_id
ORDER BY c.customer_id;

-- 8. If data on promotional campaigns (discounts, events, email marketing) is available, how could you measure their impact on customer acquisition, retention, and overall sales?
-- Sales Impact before and after campaign
SELECT 
	CASE 
		WHEN invoice_date < '2019-01-01' THEN 'Before Campaign'
		ELSE 'After Campaign'
	END AS period,
	COUNT(DISTINCT invoice_id) AS total_orders,
	SUM(total) AS total_revenue
FROM invoice
GROUP BY period;

-- Retention rate
SELECT 
    COUNT(DISTINCT customer_id) AS retained_customers
FROM invoice
WHERE invoice_date > '2019-03-31'
  AND customer_id IN (
      SELECT DISTINCT customer_id
      FROM invoice
      WHERE invoice_date BETWEEN '2019-01-01' AND '2019-03-31'
);

-- 10. How can you alter the "Albums" table to add a new column named "ReleaseYear" of type INTEGER to store the release year of each album?
ALTER TABLE album
ADD ReleaseYear INT;

SELECT * FROM album;

-- 11. Chinook is interested in understanding the purchasing behavior of customers based on their geographical location. 
-- They want to know the average total amount spent by customers from each country, along with the number of customers and the average number of tracks purchased per customer. Write an SQL query to provide this information.
WITH cus_data AS (
	SELECT
		customer_id,
        billing_country AS country,
        SUM(total) AS total_spent,
        COUNT(invoice_id) AS total_tracks
	FROM invoice
    GROUP BY customer_id, billing_country
)

SELECT
	country,
    COUNT(*) AS total_customers,
    ROUND(AVG(total_tracks),2) AS avg_tracks_per_customer,
    SUM(total_spent) AS total_spent,
    ROUND(AVG(total_spent), 2) AS avg_amount_spent_per_customer
FROM cus_data
GROUP BY country
ORDER BY country;


-- PPT graphs queries
-- Customer Demographic Distribution
SELECT
	country,
    COUNT(customer_id) AS total_customers
FROM customer
GROUP BY country
ORDER BY total_customers DESC;

-- Top 10 countries interms on revenue
SELECT
	billing_country,
    SUM(total) AS revenue
FROM invoice
GROUP BY billing_country
ORDER BY revenue DESC
LIMIT 10;

-- Top 5 genres in USA in terms on total sales
SELECT
    	g.name AS genre_name,
    	SUM(il.quantity * il.unit_price) AS total_sales,
    	RANK() OVER(ORDER BY SUM(il.quantity * il.unit_price) DESC) AS genre_rank
FROM invoice i
JOIN invoice_line il ON i.invoice_id = il.invoice_id
JOIN track t ON il.track_id = t.track_id
JOIN genre g ON t.genre_id = g.genre_id
WHERE i.billing_country = "USA"
GROUP BY g.name
ORDER BY genre_rank
LIMIT 5;
 
 -- Top 5 Artists in USA in terms of sales
SELECT
	ar.name AS artist_name,
	SUM(i.total) total_revenue,
	COUNT(t.track_id) AS total_purchases
FROM invoice i
JOIN invoice_line il ON i.invoice_id = il.invoice_id
JOIN track t ON il.track_id = t.track_id
JOIN album al ON t.album_id = al.album_id
JOIN artist ar ON al.artist_id = ar.artist_id
WHERE i.billing_country = "USA"
GROUP BY ar.name
ORDER BY total_revenue DESC
LIMIT 5;

-- Top 5 tracks sold in USA
SELECT
	al.title AS track_name,
	SUM(i.total) total_revenue,
	COUNT(t.track_id) AS total_purchases
FROM invoice i
JOIN invoice_line il ON i.invoice_id = il.invoice_id
JOIN track t ON il.track_id = t.track_id
JOIN album al ON t.album_id = al.album_id
JOIN artist ar ON al.artist_id = ar.artist_id
JOIN genre g ON t.genre_id = g.genre_id
WHERE i.billing_country = "USA"
GROUP BY al.title
ORDER BY total_revenue DESC
LIMIT 5;

-- Customer churn rate
WITH filter_data AS (
	SELECT
		DISTINCT customer_id
	FROM invoice
    WHERE invoice_date >= '2020-12-30' - INTERVAL 6 MONTH
),
chunk_customers AS (
	SELECT
		customer_id
	FROM customer
 	WHERE customer_id NOT IN (SELECT customer_id FROM filter_data)
)

SELECT
	(SELECT COUNT(DISTINCT customer_id) FROM invoice) AS total_customers,
  	(SELECT COUNT(*) FROM chunk_customers) AS total_chunk_customers,
  	ROUND(
		((SELECT COUNT(*) FROM chunk_customers) * 100)
        		/
        		(SELECT COUNT(DISTINCT customer_id) FROM invoice)
  	, 2) AS customer_chunk_rate
