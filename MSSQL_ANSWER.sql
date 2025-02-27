USE MyDatabase;
/* 
Execute each query one by one as specified.
For question 5 and 6, execute the object (function/procedure) creation first, then the queries.
*/

-- QUESTION 1:
/* 
Write an SQL query to calculate the total sales of furniture products, grouped by each quarter of the year, 
and order the results chronologically. 
*/
SELECT 
    CONCAT('Q', DATEPART(QUARTER, O.ORDER_DATE), '-', YEAR(O.ORDER_DATE)) AS Quarter_Year,
    ROUND(SUM(O.SALES), 2) AS Total_Sales
FROM ORDERS O
JOIN PRODUCT P ON O.PRODUCT_ID = P.ID
WHERE P.NAME = 'Furniture' 
GROUP BY YEAR(O.ORDER_DATE), DATEPART(QUARTER, O.ORDER_DATE)
ORDER BY YEAR(O.ORDER_DATE), DATEPART(QUARTER, O.ORDER_DATE);

-- QUESTION 2:
/* 
Analyze the impact of different discount levels on sales performance across product categories, 
specifically looking at the number of orders and total profit generated for each discount classification.

Discount level condition:
No Discount = 0
0 < Low Discount <= 0.2
0.2 < Medium Discount <= 0.5
High Discount > 0.5 

Note: The expected result in the attachment has a small difference due to the unmatched condition 
considering DISCOUNT = 0.2 as "Medium Discount", unlike the question.
*/
WITH DiscountClass AS (
    SELECT 
        P.CATEGORY AS CATEGORY,
        CASE
            WHEN O.DISCOUNT = 0 THEN 'No Discount'
            WHEN O.DISCOUNT > 0 AND O.DISCOUNT <= 0.2 THEN 'Low Discount'
            WHEN O.DISCOUNT > 0.2 AND O.DISCOUNT <= 0.5 THEN 'Medium Discount'
            WHEN O.DISCOUNT > 0.5 THEN 'High Discount'
        END AS Discount_Class,
        O.ORDER_ID,
        O.PROFIT
    FROM ORDERS O
    JOIN PRODUCT P ON O.PRODUCT_ID = P.ID           
)
SELECT 
    CATEGORY,
    Discount_Class,
    COUNT(ORDER_ID) AS Number_of_Orders,      
    ROUND(SUM(PROFIT), 2) AS Total_Profit    
FROM DiscountClass
GROUP BY CATEGORY, Discount_Class
ORDER BY CATEGORY, Discount_Class;


-- QUESTION 3:
/* 
Determine the top-performing product categories within each customer segment based on sales and profit, 
focusing specifically on those categories that rank within the top two for profitability. 
*/
SELECT 
    SEGMENT,
    CATEGORY,
    Sales_Rank,
    Profit_Rank
FROM (
    SELECT 
        C.SEGMENT,
        P.CATEGORY,
		SUM(O.SALES) AS Total_Sales,
        SUM(O.PROFIT) AS Total_Profit,
        RANK() OVER(PARTITION BY C.SEGMENT ORDER BY SUM(O.SALES) DESC) as Sales_Rank,
        RANK() OVER(PARTITION BY C.SEGMENT ORDER BY SUM(O.PROFIT) DESC) as Profit_Rank
    FROM ORDERS O
    JOIN PRODUCT P ON O.PRODUCT_ID = P.ID
    JOIN CUSTOMER C ON O.CUSTOMER_ID = C.ID
    GROUP BY C.SEGMENT, P.CATEGORY
) AS Ranked_profit
WHERE Profit_Rank <= 2
ORDER BY SEGMENT, Profit_Rank;

-- QUESTION 4
/*
Create a report that displays each employee's performance across different product categories, showing not only the 
total profit per category but also what percentage of their total profit each category represents, with the result 
ordered by the percentage in descending order for each employee.
*/
SELECT 
    E.ID_EMPLOYEE,
    P.CATEGORY,
    ROUND(SUM(O.PROFIT), 2) AS Rounded_Total_Profit,
    ROUND((SUM(O.PROFIT) / SUM(SUM(O.PROFIT)) 
		OVER (PARTITION BY E.ID_EMPLOYEE)) * 100, 2) AS Profit_Percentage
FROM ORDERS O
JOIN PRODUCT P ON O.PRODUCT_ID = P.ID
JOIN EMPLOYEES E ON O.ID_EMPLOYEE = E.ID_EMPLOYEE
GROUP BY E.ID_EMPLOYEE, P.CATEGORY
ORDER BY E.ID_EMPLOYEE, Profit_Percentage DESC;

-- QUESTION 5:
/*
Develop a user-defined function in SQL Server to calculate the profitability ratio for each product category 
an employee has sold, and then apply this function to generate a report that sorts each employee's product categories
by their profitability ratio.
*/
IF OBJECT_ID (N'dbo.CalculateProfitabilityRatio', N'FN') IS NOT NULL
    DROP FUNCTION dbo.CalculateProfitabilityRatio;
GO
CREATE FUNCTION dbo.CalculateProfitabilityRatio (
    @ID_EMPLOYEE INT, 
    @CATEGORY VARCHAR(255)
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @Total_Profit DECIMAL(10,4) = 0;
    DECLARE @Total_Sales DECIMAL(10,4) = 0;

    SELECT 
        @Total_Profit = SUM(O.PROFIT),
        @Total_Sales = SUM(O.SALES)
    FROM ORDERS O
    JOIN PRODUCT P ON O.PRODUCT_ID = P.ID
    WHERE O.ID_EMPLOYEE = @ID_EMPLOYEE
    AND P.CATEGORY = @CATEGORY;
    
    -- Avoid division by zero, return 0 if sales are 0
    RETURN CASE 
               WHEN @Total_Sales = 0 THEN 0
               ELSE ROUND(@Total_Profit / @Total_Sales, 2)
           END;
END;

SELECT 
    E.ID_EMPLOYEE,
    P.CATEGORY AS Product_Category,
    ROUND(SUM(O.SALES), 2) AS Total_Sales,
    ROUND(SUM(O.PROFIT), 2) AS Total_Profit,
    dbo.CalculateProfitabilityRatio(E.ID_EMPLOYEE, P.CATEGORY) AS Profitability_Ratio
FROM ORDERS O
JOIN PRODUCT P ON O.PRODUCT_ID = P.ID
JOIN EMPLOYEES E ON O.ID_EMPLOYEE = E.ID_EMPLOYEE
GROUP BY E.ID_EMPLOYEE, P.CATEGORY
ORDER BY E.ID_EMPLOYEE, Profitability_Ratio DESC;

-- QUESTION 6:
/* 
Write a stored procedure to calculate the total sales and profit for a specific EMPLOYEE_ID over a specified date range. 
The procedure should accept EMPLOYEE_ID, StartDate, and EndDate as parameters.
*/
IF OBJECT_ID(N'dbo.GetEmployeeSalesProfit', N'P') IS NOT NULL
    DROP PROCEDURE dbo.GetEmployeeSalesProfit;
GO
CREATE PROCEDURE dbo.GetEmployeeSalesProfit (
    @Employee_ID INT,
    @StartDate DATE,
    @EndDate DATE
)
AS
BEGIN
    DECLARE @Total_Sales DECIMAL(10,2) = 0;
    DECLARE @Total_Profit DECIMAL(10,2) = 0;
	DECLARE @Employee_Name VARCHAR(255);

	SELECT @Employee_Name = Name
    FROM EMPLOYEES
    WHERE ID_EMPLOYEE = @Employee_ID;
    
    -- Calculate total sales and profit
    SELECT 		
        @Total_Sales = SUM(SALES),
        @Total_Profit = SUM(PROFIT)
    FROM ORDERS
    WHERE ID_EMPLOYEE = @Employee_ID
    AND ORDER_DATE BETWEEN @StartDate AND @EndDate;
    
    -- Display results
    SELECT 
		@Employee_Name AS EMPLOYEE_NAME,
		@Total_Sales AS TOTAL_SALES, 
		@Total_Profit AS TOTAL_PROFIT;
END;

EXEC GetEmployeeSalesProfit @Employee_ID = 3, @StartDate = '2016-12-01', @EndDate = '2016-12-31';

-- QUESTION 7:
/*
Write a query using dynamic SQL query to calculate the total profit for the last six quarters in the datasets, 
pivoted by quarter of the year, for each state.
*/
DECLARE @DynamicSQL NVARCHAR(MAX);			
DECLARE @QuarterList NVARCHAR(MAX);			-- For grouping purposes and column names
DECLARE @QuarterListRounding NVARCHAR(MAX); -- For rounding statement

-- Prepare column names
WITH QuarterData AS (
    SELECT DISTINCT 
        CONCAT('Q', DATEPART(QUARTER, ORDER_DATE), '_', YEAR(ORDER_DATE)) AS QuarterYear,
        YEAR(ORDER_DATE) AS Year,
        DATEPART(QUARTER, ORDER_DATE) AS Quarter
    FROM ORDERS
),
LatestQuarters AS (
    SELECT TOP 6 QuarterYear 
    FROM QuarterData
    ORDER BY Year DESC, Quarter DESC
)
SELECT 
    @QuarterList = STRING_AGG(QUOTENAME(QuarterYear), ', '),
    @QuarterListRounding = STRING_AGG('ROUND(' + QUOTENAME(QuarterYear) + ', 2) AS ' + QUOTENAME(QuarterYear), ', ')
FROM LatestQuarters;

-- Construct dynamic SQL query
SET @DynamicSQL = '
SELECT STATE, ' + @QuarterListRounding + '
FROM
(
    SELECT 
        C.STATE,  
        CONCAT(''Q'', DATEPART(QUARTER, O.ORDER_DATE), ''_'', YEAR(O.ORDER_DATE)) AS QuarterYear,
        O.PROFIT AS Profit  
    FROM ORDERS O
    JOIN CUSTOMER C ON O.CUSTOMER_ID = C.ID
) AS SourceData
PIVOT
(
    SUM(Profit) FOR QuarterYear IN (' + @QuarterList + ')
) AS PivotTable
ORDER BY STATE';

-- Execute dynamic SQL query
EXEC(@DynamicSQL);

