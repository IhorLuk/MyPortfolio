/*
Data: Dataset from The National Center for Missing and Exploited Children (USA)

Used skills: join, group by(aggregate functions), temp table, convert data type, subqueries, window functions, WITH(CTEs), CASE
*/

USE MissingChildrenInUSA

-- Take a look at the whole data
SELECT *
FROM MissingChildrenInUSA_aboutChildren about
JOIN MissingChildrenInUSA_missingData miss
ON about.childid = miss.childid
ORDER BY about.childid

-- Total cases by countries 
SELECT
	missingfromcountry
	, COUNT(childid) AS totalNumber
FROM MissingChildrenInUSA_missingData
GROUP BY missingfromcountry

-- Found a couple of cases from Mexico, Canada and Philippines. We will focus on US only (2821 rows)
-- Choose only important columns and US cases, create temp table for further use.
DROP TABLE IF EXISTS #MissingChildrenUSA_forAnalysis
CREATE TABLE #MissingChildrenUSA_forAnalysis
	(childid int
	, childFirstName nvarchar(50)
	, childLastName nvarchar(50)
	, birthDate date
	, sex varchar(6)
	, race varchar(30)
	, heightInches smallint
	, weightLbs smallint
	, missingFromDate date
	, missingFromState char(2)
	, caseType varchar(50)
)
INSERT INTO #MissingChildrenUSA_forAnalysis 
SELECT 
	about.childid, about.childfirstname, about.childlastname, about.birthdate
	, about.sex , about.race, about.height_inches, about.weight_lbs
	, miss.missingfromdate, miss.missingfromstate, miss.casetype
FROM MissingChildrenInUSA_aboutChildren about
JOIN MissingChildrenInUSA_missingData miss
ON about.childid = miss.childid
WHERE miss.missingfromcountry = 'United States'

-- Check temp table
SELECT *
FROM #MissingChildrenUSA_forAnalysis

-- Percentage by sex using group by
SELECT 
	sex
	, COUNT(sex) as casesBySex
	, ROUND(CAST(COUNT(sex) as decimal(7,2))*100/(SELECT COUNT(*) FROM #MissingChildrenUSA_forAnalysis),2) as precentBySex
FROM #MissingChildrenUSA_forAnalysis
GROUP BY sex

-- Cases by race using window function
SELECT
	DISTINCT(race)
	, COUNT(race) OVER(PARTITION BY race) as totalCases
FROM #MissingChildrenUSA_forAnalysis
ORDER BY totalCases DESC

-- Now let's explore the age of children at the moment of missing in each state
SELECT
	missingFromState
	, AVG(DATEDIFF(year,birthDate,missingFromDate)) as ageWhenMissed
FROM #MissingChildrenUSA_forAnalysis
GROUP BY missingFromState
ORDER BY missingFromState

-- The whole picture by each state (number of cases, avg age, race with the largest number)
WITH commonRace as (
	SELECT 
		missingFromState
		, race
		, COUNT(childId) as numberOfChildren
		, ROW_NUMBER() OVER (partition by missingFromState order by count(childId) desc) as rowNumber
	FROM #MissingChildrenUSA_forAnalysis
	GROUP BY missingFromState, race
), commonRaceState as (
	SELECT 
		missingFromState
		, race
		, numberOfChildren
	FROM commonRace
	WHERE rowNumber = 1
)

SELECT 
	miss.missingFromState
	, race.race
	, COUNT(miss.childId) as childrenTotal
	, AVG(DATEDIFF(year,birthDate,missingFromDate)) as avgAgeWhenMissed
FROM #MissingChildrenUSA_forAnalysis miss
JOIN  commonRaceState race
ON miss.missingFromState = race.missingFromState
GROUP BY miss.missingFromState, race.race
ORDER BY miss.missingFromState
GO

-- Rolling number of missing children by year
-- Compare current year to previous using CASE expression
WITH totalCasesPerYear AS(
SELECT
	DISTINCT(YEAR(missingFromDate)) as yearOfMissing
	, COUNT(childid) OVER( PARTITION BY YEAR(missingFromDate)) as currentYearCases
	, COUNT(childid) OVER( ORDER BY YEAR(missingFromDate)) as totalCasesRolling
FROM #MissingChildrenUSA_forAnalysis
), totalCasesWithPrevious  as (
SELECT 
	yearOfMissing
	, currentYearCases, totalCasesRolling
	, LAG(currentYearCases,1,0) OVER (ORDER BY yearOfMissing) as previousYearCases
FROM totalCasesPerYear)

SELECT 
	yearOfMissing
	, currentYearCases
	, previousYearCases
	, CASE 
		WHEN previousYearCases > currentYearCases THEN 'Less cases this year'
		WHEN previousYearCases < currentYearCases THEN 'More cases this year'
		ELSE 'The same amount' 
	END AS CompareToPreviousYear
	, totalCasesRolling
FROM totalCasesWithPrevious
ORDER BY yearOfMissing
