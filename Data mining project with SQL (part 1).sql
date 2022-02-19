/* Contoso (fictional company) data mining 


CTE, Fonctions d'agrégation, Fonctions Windows, Jointures, Variables, Vues, etc. */

USE ContosoRetailDW
GO

/* 1. Identifier les produits les plus rentables par unité en termes de marge de profit */

SELECT ProductName, UnitCost, UnitPrice, (UnitPrice - UnitCost) AS UnitProfit, (((UnitPrice - UnitCost) / UnitPrice) * 100) AS ProfitMarginPercentage
FROM dbo.DimProduct 
ORDER BY ProfitMarginPercentage DESC

-- Les marges de profit varient entre 48,94% pour les produits les moins rentables et 66,88% pour les produits les plus rentables

/* 2. Créer une vue à partir d'un CTE pour calculer les profits totaux réalisés par produit */

DROP VIEW IF EXISTS CTE1View

CREATE VIEW CTE1View AS
WITH CTE1 (ProductName, TotalCost, TotalSales, TotalSalesQuantity)
AS
(
SELECT T5.ProductName, SUM(T4.TotalCost) AS TotalCost, SUM(T4.SalesAmount) AS TotalSales, SUM(T4.SalesQuantity) AS TotalSalesQuantity
FROM dbo.FactSales AS T4
LEFT JOIN dbo.DimProduct AS T5
ON T4.ProductKey = T5.ProductKey
GROUP BY T5.ProductName
)
SELECT *, (TotalSales - TotalCost) AS TotalProfit, (((TotalSales - TotalCost)/TotalSales)*100) AS TotalProfitMargin
FROM CTE1

/* 3. Identifier les produits les plus rentables en général et leur importance relative en termes de profit */

WITH CTE2 (ProductName, TotalCost, TotalSales, TotalSalesQuantity, TotalProfit, TotalProfitMargin, ProfitPercentage)
AS
(
SELECT *, ((TotalProfit*100)/7048761007.1076000000) AS ProfitPercentage
FROM CTE1View
)
SELECT *, CAST(ROUND(SUM(ProfitPercentage) OVER (ORDER BY ProfitPercentage DESC), 4) AS NUMERIC(18, 4)) AS IncrementalProfitPercentage
FROM CTE2

-- « Proseware Projector 1080p DLP86 White » est le produit ayant généré le plus de profits (34 622 150,34$), représentant 0,49% des profits totaux. De plus, à l'aide de la colonne « IncrementalProfitPercentage », nous constatons qu'un petit nombre de produits représentent un grand pourcentage des profits totaux générés. En effet, les 496 premiers produits (ou 19,71% des produits) représentent plus de 60% des profits totaux générés. Il serait donc intéressant de porter une attention particulière à ces produits

/* 4. Créer une série chronologique pour les coûts, les prix et les profits */

SELECT DateKey, SUM(TotalCost) AS TotalCost, SUM(SalesAmount) AS TotalSales, (SUM(SalesAmount) - SUM(TotalCost)) AS TotalProfit, (((SUM(SalesAmount) - SUM(TotalCost)) / SUM(SalesAmount)) * 100) AS ProfitMarginPercentage
FROM dbo.FactSales
GROUP BY DateKey 
ORDER BY DateKey

/* 5. Créer une vue pour les coûts, les ventes et les profits par date pour subséquemment calculer le profit total réalisé */

DROP VIEW IF EXISTS View1

CREATE VIEW View1 AS
SELECT DateKey, SUM(TotalCost) AS TotalCost, SUM(SalesAmount) AS TotalSales, (SUM(SalesAmount) - SUM(TotalCost)) AS TotalProfit, (((SUM(SalesAmount) - SUM(TotalCost)) / SUM(SalesAmount)) * 100)AS ProfitMarginPercentage
FROM dbo.FactSales
GROUP BY DateKey 

/* 6. Créer une variable contenant le profit total réalisé */

DECLARE @TotalProfitEver AS NUMERIC(38,10)
SELECT @TotalProfitEver = SUM(TotalProfit)
FROM View1
PRINT @TotalProfitEver

-- À utiliser lors des calculs de pourcentage de profit (profits générés par un produit ou une ville / profits totaux générés)

/* 7. Créer une vue à partir d'un CTE pour les coûts, les ventes et les profits par ville */

DROP VIEW IF EXISTS CTE2View 

CREATE VIEW CTE2View AS
WITH CTE3 (SalesTerritoryName, SalesTerritoryRegion, SalesTerritoryCountry, SalesTerritoryGroup, TotalCost, TotalSales, TotalProfit)
AS
(
SELECT SalesTerritoryName, SalesTerritoryRegion, SalesTerritoryCountry, SalesTerritoryGroup, (SUM(TotalCost)) AS TotalCost, (SUM(SalesAmount)) AS TotalSales, (SUM(SalesAmount) - SUM(TotalCost)) AS TotalProfit
FROM dbo.FactSales AS T1
LEFT JOIN dbo.DimStore AS T2
ON T1.StoreKey = T2.StoreKey
INNER JOIN dbo.DimSalesTerritory AS T3
ON T2.GeographyKey = T3.GeographyKey
GROUP BY SalesTerritoryName, SalesTerritoryRegion, SalesTerritoryCountry, SalesTerritoryGroup
)
SELECT *, ((TotalProfit*100)/7048761007.1076000000) AS ProfitPercentage
FROM CTE3

/* 8. Identifier les villes les plus rentables et leur importance relative en termes de profit */

SELECT *, CAST(ROUND(SUM(ProfitPercentage) OVER (ORDER BY ProfitPercentage DESC), 4) AS NUMERIC (18, 4)) AS IncrementalProfitPercentage
FROM CTE2View

-- « Beijing » est la ville ayant généré le plus de profits (830 021 918,73$), représentant 11,76% des profits totaux. De plus, à l'aide de la colonne « IncrementalProfitPercentage », nous constatons qu'un petit nombre de villes représentent un grand pourcentage des profits totaux générés. En effet, les 15 premières villes (ou 5,70% des villes) représentent plus de 50% des profits totaux générés. Il serait donc intéressant de porter une attention particulière à ces villes

/* 9. Créer une vue à partir d'un CTE pour calculer les profits totaux réalisés par canal */

DROP VIEW IF EXISTS CTE3View

CREATE VIEW CTE3View AS
WITH CTE4 (ChannelName, TotalCost, TotalSales, TotalSalesQuantity)
AS
(
SELECT T6.ChannelName, SUM(TotalCost) AS TotalCost, SUM(SalesAmount) AS TotalSales, SUM(SalesQuantity) AS TotalSalesQuantity
FROM dbo.FactSales AS T4
LEFT JOIN dbo.DimChannel AS T6
ON T4.channelKey = T6.channelKey
GROUP BY T6.ChannelName
)
SELECT *, (TotalSales - TotalCost) AS TotalProfit, (((TotalSales - TotalCost)/TotalSales)*100) AS TotalProfitMargin
FROM CTE4

/* 10. Identifier les canaux les plus rentables en général et leur importance relative en termes de profit */

WITH CTE5 (ChannelName, TotalCost, TotalSales, TotalSalesQuantity, TotalProfit, TotalProfitMargin, ProfitPercentage)
AS
(
SELECT *, ((TotalProfit*100)/7048761007.1076000000) AS ProfitPercentage
FROM CTE3View
)
SELECT *, CAST(ROUND(SUM(ProfitPercentage) OVER (ORDER BY ProfitPercentage DESC), 4) AS NUMERIC(18, 4)) AS IncrementalProfitPercentage
FROM CTE5

