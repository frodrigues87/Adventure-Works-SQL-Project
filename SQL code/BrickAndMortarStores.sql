-- List of Store Customers in the US
With TopStoreCustomerSales AS (
    SELECT top 30
        c.CustomerID,
        a.city,
        SUM(soh.TotalDue) as TotalSales
    FROM Sales.SalesOrderHeader soh
    JOIN Sales.Customer c ON soh.CustomerID = c.CustomerID
    JOIN Sales.Store s ON c.StoreID = s.BusinessEntityID
    JOIN Person.BusinessEntityAddress bea ON s.BusinessEntityID = bea.BusinessEntityID
    JOIN Person.Address a ON bea.AddressID = a.AddressID
    JOIN Person.StateProvince sp ON a.StateProvinceID = sp.StateProvinceID
    WHERE c.StoreID IS NOT NULL AND sp.CountryRegionCode = 'US'
    GROUP BY c.CustomerID, a.city
    Order by TotalSales DESC
), -- New query with only Indivitual Buyers in the US, excluding the cities from the top 30 Stores
RemainingCitiesIndividualSales AS (
    SELECT
        a.City,
        sp.Name AS State,
        SUM(soh.TotalDue) as TotalSales
    FROM Sales.SalesOrderHeader soh
    JOIN Sales.Customer c ON soh.CustomerID = c.CustomerID
    JOIN Person.BusinessEntityAddress bea ON c.PersonID = bea.BusinessEntityID
    JOIN Person.Address a ON bea.AddressID = a.AddressID
    JOIN Person.StateProvince sp ON a.StateProvinceID = sp.StateProvinceID
    WHERE a.City NOT IN (SELECT City FROM TopStoreCustomerSales)
    AND c.StoreID IS NULL
    AND sp.CountryRegionCode = 'US'
    GROUP BY a.City, sp.Name
) -- Top cities, counting only indidivual buyers
SELECT TOP 10
    city,
    State,
    TotalSales
FROM RemainingCitiesIndividualSales
ORDER BY TotalSales DESC;

-- List of Store Customers in the US
WITH TopStoreCustomerSales AS (
    SELECT top 30
        c.CustomerID,
        a.city,
        SUM(soh.TotalDue) as TotalSales
    FROM Sales.SalesOrderHeader soh
    JOIN Sales.Customer c ON soh.CustomerID = c.CustomerID
    JOIN Sales.Store s ON c.StoreID = s.BusinessEntityID
    JOIN Person.BusinessEntityAddress bea ON s.BusinessEntityID = bea.BusinessEntityID
    JOIN Person.Address a ON bea.AddressID = a.AddressID
    JOIN Person.StateProvince sp ON a.StateProvinceID = sp.StateProvinceID
    WHERE c.StoreID IS NOT NULL AND sp.CountryRegionCode = 'US'
    GROUP BY c.CustomerID, a.city
    ORDER BY TotalSales DESC
),
-- Individual Customers Info
ClientInfo AS (
    SELECT 
        BusinessEntityID,
        Demographics.value('declare namespace aw="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey"; 
        (/aw:IndividualSurvey/aw:TotalPurchaseYTD)[1]', 'decimal(10,2)') as TotalPurchaseYTD,
        Demographics.value('declare namespace aw="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey"; 
        (/aw:IndividualSurvey/aw:YearlyIncome)[1]', 'varchar(10)') as YearlyIncome
    FROM Person.Person
    Where PersonType = 'IN'
),
-- Average values and number of customers per city
ClientValue AS (
    SELECT
        COUNT(ci.BusinessEntityID) AS NumCustomers,
        SUM(ci.TotalPurchaseYTD) AS SumTotalPurchaseYTD,
        AVG(ci.TotalPurchaseYTD) AS AvgTotalPurchaseYTD,
        AVG(CAST(
            CASE
                WHEN CHARINDEX('-', ci.YearlyIncome) > 0
                THEN
                    (CAST(SUBSTRING(ci.YearlyIncome, 1, CHARINDEX('-', ci.YearlyIncome) - 1) AS decimal) +
                    CAST(SUBSTRING(ci.YearlyIncome, CHARINDEX('-', ci.YearlyIncome) + 1, LEN(ci.YearlyIncome)) AS decimal)) / 2
                ELSE NULL
            END AS decimal)) AS AvgYearlyIncome,
        a.City,
        sp.Name AS State
    FROM
        ClientInfo AS ci
    JOIN Person.BusinessEntityAddress bea ON ci.BusinessEntityID = bea.BusinessEntityID
    JOIN Person.Address a ON bea.AddressID = a.AddressID
    JOIN Person.StateProvince sp ON a.StateProvinceID = sp.StateProvinceID
    WHERE sp.CountryRegionCode = 'US'
    GROUP BY a.City, sp.Name
    HAVING COUNT(ci.BusinessEntityID) > 10
)
SELECT 
    NumCustomers,
    SumTotalPurchaseYTD,
    AvgTotalPurchaseYTD,
    AVGYearlyIncome,
    City,
    State
from ClientValue
Where City NOT IN (SELECT city FROM TopStoreCustomerSales)
Order by NumCustomers DESC