/*
USED: join, group by(aggregate functions), temp table 
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
	, COUNT(childid)
FROM MissingChildrenInUSA_missingData
GROUP BY missingfromcountry

-- Found couple cases from Mexico, Canada and Philippines. We will focus on US cases only (2821 total)
-- Choose only imortant columns and US cases, create temp table for further use.
DROP TABLE if exists #MissingChildrenUSA_forAnalysis
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
	about.childid
	, about.childfirstname
	, about.childlastname
	, about.birthdate
	, about.sex 
	, about.race
	, about.height_inches
	, about.weight_lbs
	, miss.missingfromdate
	, miss.missingfromstate
	, miss.casetype
FROM MissingChildrenInUSA_aboutChildren about
JOIN MissingChildrenInUSA_missingData miss
ON about.childid = miss.childid
WHERE miss.missingfromcountry = 'United States'

-- Check temp table
SELECT *
FROM #MissingChildrenUSA_forAnalysis

-- First of all take a look at amount of cases per each race
SELECT race, count(childid) as totalMissingCases
FROM MissingChildrenInUSA_aboutChildren
GROUP BY race
ORDER BY totalMissingCases DESC