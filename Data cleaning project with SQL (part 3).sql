/* Nettoyage de données avec SQL 

Outils utilisés : SQL, CTE, Excel, Fonctions d’agrégation, Fonctions Windows 

Source de données utilisée : https://github.com/metmuseum/openaccess/ 

"The Metropolitan Museum of Art presents over 5,000 years of art from around the world for everyone to experience and enjoy" */ 

USE DataCleaningProject2
GO

/* 1.1 Calculer la valeur moyenne des valeurs cohérentes de ObjectBeginDate pour subséquemment imputer aux valeurs incohérentes de la même colonne */

SELECT SUM(ObjectBeginDate) AS SommeObjectBeginDate, COUNT(*) AS NombreObjectBeginDate, SUM(ObjectBeginDate)/COUNT(*) AS MoyenneObjectBeginDate
FROM dbo.MetObjects
WHERE (ObjectBeginDate <= ObjectEndDate)
AND ( (ObjectEndDate != 0) 
OR (ObjectBeginDate != 0 AND ObjectEndDate = 0) )

-- Les valeurs sont présumées cohérentes lorsque leur date de début précède ou égale leur date de fin et lorsque leur date de fin et leur date de début ne sont pas toutes les deux égales à 0

/* 1.2 Calculer la valeur moyenne des valeurs cohérentes de ObjectEndDate pour subséquemment imputer aux valeurs incohérentes */

SELECT SUM(ObjectEndDate) AS SommeObjectEndDate, COUNT(*) AS NombreObjectEndDate, SUM(ObjectEndDate)/COUNT(*) AS MoyenneObjectEndDate
FROM dbo.MetObjects
WHERE (ObjectBeginDate <= ObjectEndDate)
AND ( (ObjectEndDate != 0) 
OR (ObjectBeginDate != 0 AND ObjectEndDate = 0) )

/* 1.3 Remplacer les valeurs incohérentes de ObjectBeginDate par 1297 et les valeurs incohérentes de ObjectEndDate par 1399 */

UPDATE dbo.MetObjects
SET ObjectBeginDate = 1297,
    ObjectEndDate = 1399
WHERE (ObjectBeginDate = 0 AND ObjectEndDate = 0)
OR (ObjectBeginDate > ObjectEndDate)

-- Les valeurs sont présumées incohérentes lorsque leur date de fin précède leur date de début ou lorsque leur date de fin et leur date de début sont toutes les deux égales à 0

/* 2. Standardiser les formats de ObjectDate */

UPDATE dbo.MetObjects
SET ObjectDate = 
CASE 
WHEN ObjectBeginDate < 0 AND ObjectEndDate < 0 THEN CONCAT(ABS(ObjectBeginDate), ' BC', ' - ', ABS(ObjectEndDate), ' BC') 
WHEN ObjectBeginDate < 0 AND ObjectEndDate >= 0 THEN CONCAT(ABS(ObjectBeginDate), ' BC', ' - ', 'AD ', ABS(ObjectEndDate)) 
ELSE CONCAT('AD ', ObjectBeginDate,' - ', 'AD ', ObjectEndDate)
END

-- Format recherché : DateDébut(BC ou AD)-DateFin(BC ou AD) en valeur absolue

/* 3. Remplacer les valeurs NULL ou manquantes par Unknown */

UPDATE dbo.MetObjects
SET GalleryNumber = 
CASE
WHEN GalleryNumber IS NULL THEN 'Unknown'
WHEN GalleryNumber = ' ' THEN 'Unknown' 
ELSE GalleryNumber
END 

UPDATE dbo.MetObjects
SET Culture = 
CASE
WHEN Culture IS NULL THEN 'Unknown'
WHEN Culture = ' ' THEN 'Unknown' 
ELSE Culture
END 

/* 4.1 Décomposer l'adresse Repository en colonnes individuelles à l'aide des virgules */

-- Les adresses sont toutes dans le même format : Nom, Ville, État (e.g. Metropolitan Museum of Art, New York, NY)

-- Pour prélever le nom, extraire à partir de la gauche tous les caractères jusqu'à l'occurrence de la première virgule (exclue)

ALTER TABLE dbo.MetObjects
ADD RepositoryName NVARCHAR (255); 

UPDATE dbo.MetObjects
SET RepositoryName = SUBSTRING(Repository, 1, (CHARINDEX(',', Repository) -1)) 

-- Pour prélever la ville, extraire à partir de la première virgule tous les caractères jusqu'à l'occurrence de la deuxième virgule

ALTER TABLE dbo.MetObjects
ADD RepositoryCity NVARCHAR (255); 

UPDATE dbo.MetObjects
SET RepositoryCity = 
SUBSTRING(Repository, CHARINDEX(',', Repository, 1) +1, CHARINDEX(',', Repository, CHARINDEX(',', Repository)+1) - CHARINDEX(',', Repository) -1)

-- Pour prélever l'état, extraire à partir de la droite tous les caractères jusqu'à l'occurrence de la première virgule (de droite à gauche)

ALTER TABLE dbo.MetObjects
ADD RepositoryState NVARCHAR (255); 

UPDATE dbo.MetObjects
SET RepositoryState = RIGHT(Repository, CHARINDEX(',', REVERSE(Repository))-1) 

/* 4.2 Supprimer l'adresse Repository (colonne désormais inutile) */

ALTER TABLE dbo.MetObjects
DROP COLUMN Repository

/* 5. Remplacer les 0 par Non et les 1 par Oui */

ALTER TABLE dbo.MetObjects
ALTER COLUMN IsHighlight NVARCHAR(255)

-- Transformer d'abord le type de données de BIT à NVARCHAR

UPDATE dbo.MetObjects
SET IsHighlight = 
CASE 
WHEN IsHighlight = 1 THEN 'Yes' 
WHEN IsHighlight = 0 THEN 'No'
ELSE IsHighlight
END

ALTER TABLE dbo.MetObjects
ALTER COLUMN IsTimelineWork NVARCHAR(255)

UPDATE dbo.MetObjects
SET IsTimelineWork = 
CASE 
WHEN IsTimelineWork = 1 THEN 'Yes' 
WHEN IsTimelineWork = 0 THEN 'No'
ELSE IsTimelineWork
END

ALTER TABLE dbo.MetObjects
ALTER COLUMN IsPublicDomain NVARCHAR(255)

UPDATE dbo.MetObjects
SET IsPublicDomain = 
CASE 
WHEN IsPublicDomain = 1 THEN 'Yes' 
WHEN IsPublicDomain = 0 THEN 'No'
ELSE IsPublicDomain
END

/* 6. Supprimer les duplications présumées (lorsque ObjectNumber, AccessionYear, ObjectDate et RepositoryName sont identiques) */

WITH CTENombreLignes AS(
SELECT *,
ROW_NUMBER() OVER(PARTITION BY ObjectNumber, AccessionYear, ObjectDate, RepositoryName
ORDER BY ObjectNumber) AS NombreLignes
FROM dbo.MetObjects
)
DELETE
FROM CTENombreLignes 
WHERE NombreLignes > 1

-- Créer d'abord une table temporaire CTE pour trouver les duplications présumées (lorsque NombreLignes > 1), puis agir sur cette table temporaire pour supprimer les duplications 


