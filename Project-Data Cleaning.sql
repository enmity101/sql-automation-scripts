-- SQL Project - Data Cleaning - world_layoffs

-- https://www.kaggle.com/datasets/swaptr/layoffs-2022






SELECT * 
FROM world_layoffs.layoffs;


-- The initial step involves creating a staging table. This table serves as the working environment for all data‑cleaning operations,while the original dataset remains preserved as a backup.
-- Maintaining the raw data separately ensures that any errors or issues encountered during cleaning can be resolved without compromising the integrity of the source.
CREATE TABLE world_layoffs.layoffs_staging 
LIKE world_layoffs.layoffs;

INSERT layoffs_staging 
SELECT * FROM world_layoffs.layoffs;


-- Step 1: Create a staging table as a workspace for cleaning
-- The raw dataset remains preserved separately as a backup

-- Data cleaning process generally includes:
-- 1. Identify and remove duplicate records
-- 2. Standardize values and correct inconsistencies
-- 3. Review and handle null entries
-- 4. Eliminate unnecessary columns or rows



-- Step 1: Remove duplicate records
-- Begin by checking the dataset for duplicate entries



SELECT *
FROM world_layoffs.layoffs_staging
;

SELECT company, industry, total_laid_off,`date`,
		ROW_NUMBER() OVER (
			PARTITION BY company, industry, total_laid_off,`date`) AS row_num
	FROM 
		world_layoffs.layoffs_staging;



SELECT *
FROM (
	SELECT company, industry, total_laid_off,`date`,
		ROW_NUMBER() OVER (
			PARTITION BY company, industry, total_laid_off,`date`
			) AS row_num
	FROM 
		world_layoffs.layoffs_staging
) duplicates
WHERE 
	row_num > 1;
    
-- Verify entries for 'Oda' to confirm whether duplicates are legitimate
SELECT *
FROM world_layoffs.layoffs_staging
WHERE company = 'Oda'
;
-- These entries appear valid and should not be deleted
-- Each row must be reviewed carefully for accuracy

-- these are our real duplicates 
SELECT *
FROM (
	SELECT company, location, industry, total_laid_off,percentage_laid_off,`date`, stage, country, funds_raised_millions,
		ROW_NUMBER() OVER (
			PARTITION BY company, location, industry, total_laid_off,percentage_laid_off,`date`, stage, country, funds_raised_millions
			) AS row_num
	FROM 
		world_layoffs.layoffs_staging
) duplicates
WHERE 
	row_num > 1;

-- Delete duplicate rows where the row number is greater than 1

-- now you may want to write it like this:
WITH DELETE_CTE AS 
(
SELECT *
FROM (
	SELECT company, location, industry, total_laid_off,percentage_laid_off,`date`, stage, country, funds_raised_millions,
		ROW_NUMBER() OVER (
			PARTITION BY company, location, industry, total_laid_off,percentage_laid_off,`date`, stage, country, funds_raised_millions
			) AS row_num
	FROM 
		world_layoffs.layoffs_staging
) duplicates
WHERE 
	row_num > 1
)
DELETE
FROM DELETE_CTE
;


WITH DELETE_CTE AS (
	SELECT company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions, 
    ROW_NUMBER() OVER (PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions) AS row_num
	FROM world_layoffs.layoffs_staging
)
DELETE FROM world_layoffs.layoffs_staging
WHERE (company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions, row_num) IN (
	SELECT company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions, row_num
	FROM DELETE_CTE
) AND row_num > 1;

-- Alternative solution: add a column for row numbers
-- Delete rows where row_num > 1, then drop the column
-- so let's do it!!

ALTER TABLE world_layoffs.layoffs_staging ADD row_num INT;


SELECT *
FROM world_layoffs.layoffs_staging
;

CREATE TABLE `world_layoffs`.`layoffs_staging2` (
`company` text,
`location`text,
`industry`text,
`total_laid_off` INT,
`percentage_laid_off` text,
`date` text,
`stage`text,
`country` text,
`funds_raised_millions` int,
row_num INT
);

INSERT INTO `world_layoffs`.`layoffs_staging2`
(`company`,
`location`,
`industry`,
`total_laid_off`,
`percentage_laid_off`,
`date`,
`stage`,
`country`,
`funds_raised_millions`,
`row_num`)
SELECT `company`,
`location`,
`industry`,
`total_laid_off`,
`percentage_laid_off`,
`date`,
`stage`,
`country`,
`funds_raised_millions`,
		ROW_NUMBER() OVER (
			PARTITION BY company, location, industry, total_laid_off,percentage_laid_off,`date`, stage, country, funds_raised_millions
			) AS row_num
	FROM 
		world_layoffs.layoffs_staging;

-- Delete rows where row_num is greater than 1 to remove duplicates

DELETE FROM world_layoffs.layoffs_staging2
WHERE row_num >= 2;







-- 2. Standardize Data

SELECT * 
FROM world_layoffs.layoffs_staging2;

-- Check the industry column for null or empty values
SELECT DISTINCT industry
FROM world_layoffs.layoffs_staging2
ORDER BY industry;

SELECT *
FROM world_layoffs.layoffs_staging2
WHERE industry IS NULL 
OR industry = ''
ORDER BY industry;

-- let's take a look at these
SELECT *
FROM world_layoffs.layoffs_staging2
WHERE company LIKE 'Bally%';
-- nothing wrong here
SELECT *
FROM world_layoffs.layoffs_staging2
WHERE company LIKE 'airbnb%';

-- Example: Airbnb should be classified as Travel, but the industry field is not populated
-- Apply an update query: if another row for the same company has a valid industry,
-- use that value to fill the null entry automatically
-- This approach scales efficiently for large datasets without manual checks

-- Convert blank industry values to NULL for easier handling
UPDATE world_layoffs.layoffs_staging2
SET industry = NULL
WHERE industry = '';

-- now if we check those are all null

SELECT *
FROM world_layoffs.layoffs_staging2
WHERE industry IS NULL 
OR industry = ''
ORDER BY industry;

-- now we need to populate those nulls if possible

UPDATE layoffs_staging2 t1
JOIN layoffs_staging2 t2
ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
AND t2.industry IS NOT NULL;

-- Bally's is the only company without a populated industry value to update null entries
SELECT *
FROM world_layoffs.layoffs_staging2
WHERE industry IS NULL 
OR industry = ''
ORDER BY industry;

-- ---------------------------------------------------

-- Standardize all variations of 'Crypto' to a single value: 'Crypto'
SELECT DISTINCT industry
FROM world_layoffs.layoffs_staging2
ORDER BY industry;

UPDATE layoffs_staging2
SET industry = 'Crypto'
WHERE industry IN ('Crypto Currency', 'CryptoCurrency');

-- now that's taken care of:
SELECT DISTINCT industry
FROM world_layoffs.layoffs_staging2
ORDER BY industry;

-- --------------------------------------------------
-- we also need to look at 

SELECT *
FROM world_layoffs.layoffs_staging2;

-- Standardize country values: remove trailing period from 'United States.'
SELECT DISTINCT country
FROM world_layoffs.layoffs_staging2
ORDER BY country;

UPDATE layoffs_staging2
SET country = TRIM(TRAILING '.' FROM country);
-- Verify that country values are standardized
SELECT DISTINCT country
FROM world_layoffs.layoffs_staging2
ORDER BY country;

-- Fix date column formatting
SELECT *
FROM world_layoffs.layoffs_staging2;

-- Update date values using STR_TO_DATE
UPDATE layoffs_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

-- Convert date column to proper DATE type
ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;

SELECT *
FROM world_layoffs.layoffs_staging2;

-- Step 3: Review null values
-- Nulls in total_laid_off, percentage_laid_off, and funds_raised_millions are acceptable
-- Keeping them as NULL simplifies calculations during EDA

-- Step 4: Remove unnecessary rows and columns
SELECT *
FROM world_layoffs.layoffs_staging2
WHERE total_laid_off IS NULL;

SELECT *
FROM world_layoffs.layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

-- Delete rows with no useful data
DELETE FROM world_layoffs.layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

SELECT *
FROM world_layoffs.layoffs_staging2;

-- Drop helper column row_num
ALTER TABLE layoffs_staging2
DROP COLUMN row_num;

SELECT *
FROM world_layoffs.layoffs_staging2;


































