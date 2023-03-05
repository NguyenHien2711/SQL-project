--A. Preparing data for analysis 
--1. Check missing data, duplicate value 

SELECT Row_ID, COUNT(Row_ID) 
FROM superstore
GROUP BY Row_ID
HAVING COUNT(Row_ID) >1 

SELECT 
COUNT([Row_ID]) as Row_ID, 
COUNT([Order_ID]) as Order_ID,
COUNT([Order_Date])as [Order_Date],
COUNT([Ship_Date]) as [Ship_Date],
COUNT([Ship_Mode]) as [Ship_Mode],
COUNT([Customer_ID]) as [Customer_ID],
COUNT([Customer_First_Name]) as [Customer_First_Name],
COUNT([Customer_Last_Name]) as [Customer_Last_Name],
COUNT([Segment]) as [Segment],
COUNT([Address]) as [Address],
COUNT([Postal_Code]) as [Postal_Code],
COUNT([Region])as [Region],
COUNT([Product_ID]) as [Product_ID],
COUNT([Category]) as [Category],
COUNT([Sub_Category]) as [Sub_Category],
COUNT([Product_Name]) as [Product_Name],
COUNT([Sales]) as [Sales],
COUNT([Quantity]) as [Quantity],
COUNT([Discount]) as [Discount],
COUNT([Profit]) as [Profit]
FROM superstore 

SELECT * FROM superstore WHERE [Profit] is null 

--2. Cleaning data and convert data 
--Concatenate First and Last Name by using concat 
--Split Address column 
--Adjust inaccurate values through using case
--Filter out unwanted records

SELECT Ship_Mode, count(Ship_Mode)
From superstore
GROUP BY Ship_Mode

SELECT Segment, count(Segment)
From superstore
GROUP BY Segment

SELECT 
CASE WHEN Segment = 'Hom Ofice' THEN 'Home Office'
WHEN Segment = 'Cororate' OR Segment = 'Corporates' THEN 'Corporate'
WHEN Segment = 'C' OR Segment = 'Consu' THEN 'Consumer'
else Segment
end 
From superstore;

DROP VIEW IF exists [superstore_clean]
CREATE VIEW [superstore_clean] AS 
SELECT 
[Row_ID],
[Order_ID],
[Order_Date],
[Ship_Date],
[Ship_Mode],
[Customer_ID],
Full_name = CONCAT([Customer_First_Name], ' ',[Customer_Last_Name]),
Segment = CASE WHEN Segment = 'Hom Ofice' THEN 'Home Office'
WHEN Segment = 'Cororate' OR Segment = 'Corporates' THEN 'Corporate'
WHEN Segment = 'C' OR Segment = 'Consu' THEN 'Consumer'
else Segment
end, 
Country = REVERSE(PARSENAME(REPLACE(REVERSE([Address]), ',', '.'), 1)), 
City = REVERSE(PARSENAME(REPLACE(REVERSE([Address]), ',', '.'), 2)), 
Address = REVERSE(PARSENAME(REPLACE(REVERSE([Address]), ',', '.'), 3)),
[Region],
[Category],
[Sub_Category],
[Product_Name],
[Sales],
[Quantity],
[Discount],
[Profit]
From superstore

--B. Data Analysis Trending the time 
--1. Yearly sales, Monthly sales in each City, Category
SELECT SUM(Sales) as Total_Sale, 
SUM(Quantity) as Total_Quantity, 
SUM(Profit) as Total_Profit,
Year([Ship_Date]) AS Year 
FROM superstore_clean 
GROUP BY Year([Ship_Date])
ORDER BY Year([Ship_Date])
--The amount of sales experienced an upward trends during the period shown
--Average sales per order month
SELECT AVG(Sales) as Avg_Sale, 
Month([Ship_Date]) as Month 
FROM superstore_clean 
GROUP BY Month([Ship_Date])
ORDER BY Avg_Sale DESC
--The average sale per order in March recored highest value, at around 300$
--The lowest figure was seen in the number of sales in February, reach a record low of 180$

SELECT SUM(Sales) as Sum_Sale, 
Month([Ship_Date]) as Month 
FROM superstore_clean 
GROUP BY Month([Ship_Date])
ORDER BY Sum_Sale DESC
--The highest and lowest number of sales was recored in December at $277621.1 
--It is clearly seen that the total sale and average sales per Order in February are account for the least percentage of total sales.
--In the meanwhile, the total sales in March are relatively lower compared to that in December, regardless of having the highest number of sales per order 

WITH cate AS
(SELECT [Category],
SUM(Sales) as Total_Sale
FROM superstore_clean
GROUP BY [Category])
SELECT 
Total_Sale, [Category],
Total_Sale*100/SUM(Total_Sale) OVER () AS pct_total
FROM cate
-- The number of sales of technology account for the highest proportion, at approximately 37%,
-- follow by the figures for Furniture and Office Supplies at nearly 32% and 31% respectively.

SELECT TOP 3 [City],
SUM(Sales) as Sum_Sale
FROM superstore_clean 
GROUP BY [City]
ORDER BY Sum_Sale DESC
--Top 3 contries have the marjority of sales including New York City, Los Angeles and San Francisco

--C. ROLLING TIME WINDOW, RANK 
--1. What is the 3-month moving average of the sale in each region, category 
WITH date_month AS
(SELECT Region, YEAR(Ship_Date) AS Year, MONTH(Ship_Date) as Month, SUM(Sales) AS Sales 
FROM superstore_clean
GROUP BY Region, YEAR(Ship_Date), MONTH(Ship_Date))

SELECT *,
AVG(Sales) over (partition by Region order by Year, Month 
rows between 2 preceding and current row) as moving_avg
from date_month
--What is the 3-day moving average of the sale in each region
SELECT [Region], ([Order_Date]), 
AVG(Sales) over (partition by Region order by [Order_Date], [Order_Date] 
rows between 2 preceding and current row) as moving_avg
from superstore_clean 
--What is the 3-month moving average of the sale in each category 
WITH category_avg AS
(SELECT Category, YEAR(Ship_Date) AS Year, MONTH(Ship_Date) as Month, SUM(Sales) AS Sales 
FROM superstore_clean
GROUP BY Category, YEAR(Ship_Date), MONTH(Ship_Date))

SELECT *,
AVG(Sales) over (partition by Category order by Year, Month 
rows between 2 preceding and current row) as moving_avg
from category_avg

--2. What is the percent change in yearly sale in each region  
WITH year AS
(SELECT Region, YEAR(Order_Date) as Year, sum(Sales) as Total
FROM superstore_clean
group by Region, YEAR(Order_Date)),
pre_count AS(
SELECT *,
ISNULL(LAG(Total) over (partition by Region order by Year),0) as pre_sales
FROM year),
pct AS(
SELECT *, (Total-pre_sales)*100/Total AS pc
FROM pre_count)
SELECT * FROM pct
--3. What is the percent change in monthly sale in each region  
WITH year AS
(SELECT Region, YEAR(Order_Date) as Year, MONTH(Order_Date) as Month, sum(Sales) as Total
FROM superstore_clean
group by Region, YEAR(Order_Date),  MONTH(Order_Date)),
pre_count AS(
SELECT *,
ISNULL(LAG(Total) over (partition by Region order by Year, Month),0) as pre_sales
FROM year),
pct AS(
SELECT *, ROUND((Total-pre_sales)*100/Total,2) AS pc
FROM pre_count)
SELECT * FROM pct

--4. Which month recored the lowest and highest sales for each category

WITH cate AS
(SELECT [Category], YEAR([Order_Date]) AS Year, MONTH([Order_Date]) AS Month,
ROUND(SUM(Sales),2) as Total
FROM [dbo].[superstore_clean]
GROUP BY [Category], YEAR([Order_Date]), MONTH([Order_Date])
),
rank_sale AS
(SELECT *, RANK() OVER (PARTITION BY [Category],Year ORDER BY Total) as rk
FROM cate)

SELECT * FROM rank_sale 
WHERE rk = 1 or rk in (SELECT max(rk) from rank_sale)