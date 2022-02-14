/* Microsoft Contoso BI (vente au d�tail) data mining 

CTE, Fonctions d'agr�gation, Fonctions Windows, Jointures, Variables, Vues etc. */

USE ContosoRetailDW
GO

/* 1. Identifier les produits les plus rentables par unit� en termes de marge de profit */

SELECT ProductName, UnitCost, UnitPrice, (UnitPrice - UnitCost) AS UnitProfit, (((UnitPrice - UnitCost) / UnitPrice) * 100) AS ProfitMarginPercentage
FROM dbo.DimProduct 
ORDER BY ProfitMarginPercentage DESC

-- Les marges de profit varient entre 48,94% pour les produits les moins rentables et 66,88% pour les produits les plus rentables

/* 2. Cr�er une vue � partir d'un CTE pour calculer les profits totaux r�alis�s par produit */

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

/* 3. Identifier les produits les plus rentables en g�n�ral et leur importance relative */

WITH CTE2 (ProductName, TotalCost, TotalSales, TotalSalesQuantity, TotalProfit, TotalProfitMargin, ProfitPercentage)
AS
(
SELECT *, ((TotalProfit*100)/7048761007.1076000000) AS ProfitPercentage
FROM CTE1View
)
SELECT *, CAST(ROUND(SUM(ProfitPercentage) OVER (ORDER BY ProfitPercentage DESC), 4) AS NUMERIC(18, 4)) AS IncrementalProfitPercentage
FROM CTE2


-- � Proseware Projector 1080p DLP86 White � est le produit ayant g�n�r� le plus de profits (34 622 150,34$), repr�sentant 0,49% des profits totaux. De plus, � l'aide de la colonne � IncrementalRetailProfitPercentage �, nous constatons qu'un petit nombre de produits repr�sentent un grand pourcentage des profits totaux g�n�r�s. En effet, les 496 premiers produits (ou 19,71% des produits) repr�sentent plus de 60% des profits totaux g�n�r�s. Il serait donc int�ressant de porter une attention particuli�re � ces produits

/* 4. Cr�er une s�rie chronologique pour les co�ts, les prix et les profits */

SELECT DateKey, SUM(TotalCost) AS TotalCost, SUM(SalesAmount) AS TotalSales, (SUM(SalesAmount) - SUM(TotalCost)) AS TotalProfit, (((SUM(SalesAmount) - SUM(TotalCost)) / SUM(SalesAmount)) * 100) AS ProfitMarginPercentage
FROM dbo.FactSales
GROUP BY DateKey 
ORDER BY DateKey

-- Cette requ�te servira � construire des visualisations de donn�es de s�ries temporelles

/* 5. Cr�er une vue pour les co�ts, les ventes et les profits par date pour subs�quemment calculer le profit total r�alis� (points de vente physiques) */

DROP VIEW IF EXISTS View1

CREATE VIEW View1 AS
SELECT DateKey, SUM(TotalCost) AS TotalCost, SUM(SalesAmount) AS TotalSales, (SUM(SalesAmount) - SUM(TotalCost)) AS TotalProfit, (((SUM(SalesAmount) - SUM(TotalCost)) / SUM(SalesAmount)) * 100)AS ProfitMarginPercentage
FROM dbo.FactSales
GROUP BY DateKey 

/* 6. Cr�er une variable contenant le profit total r�alis� */

DECLARE @TotalProfitEver AS NUMERIC(38,10)
SELECT @TotalProfitEver = SUM(TotalProfit)
FROM View1
PRINT @TotalProfitEver

-- � utiliser lors des calculs de pourcentage de profit (profits g�n�r�s par un produit ou une ville / profits totaux g�n�r�s)

/* 7. Cr�er une vue � partir d'un CTE pour les co�ts, les ventes et les profits par ville */

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

/* 8. Identifier les villes les plus profitables et leur importance relative en termes de profit */

SELECT *, CAST(ROUND(SUM(ProfitPercentage) OVER (ORDER BY ProfitPercentage DESC), 4) AS NUMERIC (18, 4)) AS IncrementalProfitPercentage
FROM CTE2View

-- � Beijing � est la ville ayant g�n�r� le plus de profits en magasin (830 021 918,73$), repr�sentant 11,76% des profits totaux. De plus, � l'aide de la colonne � IncrementalProfitPercentage �, nous constatons qu'un petit nombre de villes repr�sentent un grand pourcentage des profits totaux g�n�r�s. En effet, les 15 premi�res villes (ou 5,70% des villes) repr�sentent plus de 50% des profits totaux g�n�r�s par les points de vente physiques. Il serait donc int�ressant de porter une attention particuli�re � ces villes.

/* 9. Cr�er une vue � partir d'un CTE pour calculer les profits totaux r�alis�s par canal */

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

/* 10. Identifier les canaux les plus rentables en g�n�ral et leur importance relative */

WITH CTE5 (ChannelName, TotalCost, TotalSales, TotalSalesQuantity, TotalProfit, TotalProfitMargin, ProfitPercentage)
AS
(
SELECT *, ((TotalProfit*100)/7048761007.1076000000) AS ProfitPercentage
FROM CTE3View
)
SELECT *, CAST(ROUND(SUM(ProfitPercentage) OVER (ORDER BY ProfitPercentage DESC), 4) AS NUMERIC(18, 4)) AS IncrementalProfitPercentage
FROM CTE5

