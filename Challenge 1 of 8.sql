DROP SCHEMA IF EXISTS dannys_diner;
CREATE SCHEMA dannys_diner;
USE dannys_diner;
CREATE TABLE sales (
  customer_id VARCHAR(1),
  order_date DATE,
  product_id INTEGER
);

INSERT INTO sales
  (customer_id, order_date, product_id)
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
 

CREATE TABLE menu (
  product_id INTEGER,
  product_name VARCHAR(5),
  price INTEGER
);

INSERT INTO menu
  (product_id, product_name, price)
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  
CREATE TABLE members (
  customer_id VARCHAR(1),
  join_date DATE
);

INSERT INTO members
  (customer_id, join_date)
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');
  
-- 1. What is the total amount each customer spent at the restaurant?
   SELECT s.customer_id, 
		  sum(m.price) AS spend_per_customer 
   FROM sales s 
   LEFT JOIN menu m
		ON s.product_id = m.product_id 
   GROUP BY s.customer_id
   ORDER BY sum(m.price) DESC;
   
-- 2.	How many days has each customer visited the restaurant?
  SELECT customer_id, 
		COUNT(DISTINCT order_date) AS no_of_visit 
  FROM sales 
  GROUP BY customer_id 
  ORDER BY COUNT(DISTINCT order_date) DESC;
  
-- 3.	What was the first item from the menu purchased by each customer?
WITH ordered_row AS 
	(SELECT *, 
		DENSE_RANK () OVER (PARTITION BY customer_id ORDER BY order_date) AS first_purchase 
	FROM sales)
SELECT o.customer_id, m.product_name
FROM ordered_row o
LEFT JOIN menu m
	ON o.product_id = m.product_id
WHERE first_purchase = 1
GROUP BY o.customer_id, m.product_name;

-- 4.	What is the most purchased item on the menu and how many times was it purchased by all customers?
WITH merged_table AS
	(SELECT s.customer_id, s.order_date, s.product_id, m.product_name, m.price
    FROM sales s
    LEFT JOIN menu m
    ON s.product_id = m.product_id
    )
SELECT product_name, MAX(purchase) AS total_purchase
FROM
	   (
		SELECT mt.product_name, COUNT(mt.product_id) AS purchase 
		FROM merged_table AS mt
		GROUP BY mt.product_name 
		ORDER BY COUNT(mt.product_id) DESC) sub;
        
-- 5.	Which item was the most popular for each customer?
WITH combined_table AS(
					SELECT s.customer_id,
							s.product_id,
                            m.product_name,
                            COUNT(customer_id) AS purchase,
							RANK () OVER (PARTITION BY customer_id ORDER BY COUNT(customer_id) DESC) ranked_column 
					FROM sales s
					LEFT JOIN menu m 
						 ON s.product_id = m.product_id
					GROUP BY s.customer_id,s.product_id,m.product_name
                    )
SELECT customer_id,
		product_name, 
        purchase
FROM combined_table
WHERE ranked_column = 1;

-- 6.	Which item was purchased first by the customer after they became a member?
WITH combined_view AS 
	(SELECT s.customer_id, 
			m.product_name,
			ms.join_date,
            s.order_date,
            ROW_NUMBER () OVER (PARTITION BY customer_id ORDER BY s.order_date ASC)  AS ordered_col
	FROM sales s
	LEFT JOIN menu m
		ON s.product_id = m.product_id
	LEFT JOIN members ms
		ON s.customer_id = ms.customer_id
	WHERE ms.join_date <= s.order_date)
SELECT customer_id, product_name, join_date, order_date
FROM combined_view
WHERE ordered_col = 1;

-- 7.	Which item was purchased just before the customer became a member
WITH combined_view AS 
	(SELECT s.customer_id, 
			m.product_name,
			ms.join_date,
            s.order_date,
            DENSE_RANK () OVER (PARTITION BY customer_id ORDER BY s.order_date ASC)  AS ordered_col
	FROM sales s
	LEFT JOIN menu m
		ON s.product_id = m.product_id
	LEFT JOIN members ms
		ON s.customer_id = ms.customer_id
	WHERE ms.join_date > s.order_date)
SELECT customer_id, product_name 
FROM combined_view
WHERE  ordered_col = 1;

-- 8.	What is the total items and amount spent for each member before they became a member?
WITH combined_view AS 
	(SELECT s.customer_id,
			s.product_id,
			m.product_name,
			ms.join_date,
            s.order_date,
            m.price,            
            DENSE_RANK () OVER (PARTITION BY customer_id ORDER BY s.order_date ASC)  AS ordered_col
	FROM sales s
	LEFT JOIN menu m
		ON s.product_id = m.product_id
	LEFT JOIN members ms
		ON s.customer_id = ms.customer_id
	WHERE ms.join_date > s.order_date)
SELECT customer_id, COUNT(product_id) AS total_items, SUM(price) AS amount_spent
FROM combined_view
GROUP BY customer_id
;

-- 9.	If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

SELECT s.customer_id, 
	   SUM(CASE 
			WHEN s.product_id = 1 THEN m.price * 20
			ELSE m.price * 10
            END) total_points
FROM sales s 
LEFT JOIN menu m 
	ON s.product_id = m.product_id
GROUP BY s.customer_id;

/* 10.	In the first week after a customer joins the program (including their join date) they earn 2x points 
		on all items, not just sushi - how many points do customer A and B have at the end of January?*/
SELECT s.customer_id, 
		SUM(CASE
				WHEN m.product_name = "sushi" THEN price *20
				WHEN order_date BETWEEN join_date AND DATE_ADD(mbs.join_date, INTERVAL 6 DAY) THEN price * 20
				ELSE price * 10
	   END) AS total_points
FROM sales s 
LEFT JOIN menu m 
	ON s.product_id = m.product_id
LEFT JOIN members mbs
	ON s.customer_id = mbs.customer_id
WHERE s.order_date < '2021-02-01' AND join_date IS NOT NULL
GROUP BY s.customer_id
;
-- Bonus Question 1
SELECT s.customer_id,
	   s.order_date,
	   m.product_name,
	   m.price,
       CASE
			WHEN s.order_date >= mbs.join_date THEN "Y"
            ELSE "N"
	   END AS "member"
FROM sales s
LEFT JOIN menu m
	 ON s.product_id = m.product_id
LEFT JOIN members mbs
	 ON s.customer_id = mbs.customer_id;
     
     
-- Bonus Question 2     
WITH extracted_table AS
					(SELECT s.customer_id,
						    s.order_date,
						    m.product_name,
						    m.price,
						    CASE
								WHEN s.order_date >= mbs.join_date THEN "Y"
								ELSE "N"
						    END AS "member"
					FROM sales s
					LEFT JOIN menu m
						ON s.product_id = m.product_id
					LEFT JOIN members mbs
						ON s.customer_id = mbs.customer_id)
	SELECT *,
		   CASE 
				WHEN et.member = "N" THEN "null"
				ELSE DENSE_RANK () OVER (PARTITION BY et.customer_id, et.member ORDER BY et.order_date)
       END ranking
FROM extracted_table et;
