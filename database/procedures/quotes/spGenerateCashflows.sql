alter proc Quotes.spGenerateCashflows @QuoteRunID int, @RunID int
as
--===============================================================================
-- perform run and QuoteRun setup
--===============================================================================
-- get run info 
-- declare @RunID int = 1
select
	*
into
	#runinfo
from
	ParameterTables.ParameterRuns
where
	RunID = @RunID

-- get QuoteRun info
-- declare @QuoteRunID int = 1
select
	*
into
	#QuoteRunInfo
from
	Quotes.QuoteRuns
where
	ID = @QuoteRunID

--===============================================================================
-- create results table
--===============================================================================
create table #cashflows
	(ID int identity, 
	QuoteRunID int, 
	cashflowDate date, 
	[Maturity(months)] int, 
	Age float, 
	Benefit money, 
	inflationFactor float, 
	discountFactor float, 
	probabilityOfSurvival float)

-- generate dates
set nocount on

declare @startDate date = dateadd(m, 1, dateadd(d, 1-day(getdate()), getdate()))
declare @endDate date = dateadd(year, 120, (select DateOfBirth from #QuoteRunInfo))

while @startDate <= @endDate
begin
	insert into #cashflows
		(QuoteRunID,
		cashflowDate,
		[Maturity(months)])
	values
		((select ID from #QuoteRunInfo), @startDate, DATEDIFF(m, getdate(), @startDate)-1)
	set @startDate = DATEADD(m, 1, @startDate)
end

set nocount off

-- update ages
update cf
set Age = DATEDIFF(m, DateOfBirth, cashflowDate)/12.0
from
	#cashflows cf
	inner join #QuoteRunInfo qri on cf.QuoteRunID = qri.ID

-- update benefits
update cf
set Benefit = ISNULL(qri.Benefit,0)
from
	#cashflows cf
	left join #QuoteRunInfo qri on cf.QuoteRunID = qri.ID
		and cf.cashflowDate >= qri.DateOfRetirement

-- update inflationFactor
update cf
set inflationFactor = isnull(
						power(
							1.0+qri.AnnualInflation,
							floor(DATEDIFF(m, qri.InflationDate, cashflowDate)/12.0)
							)
							,1.0)
from
	#cashflows cf
	left join #QuoteRunInfo qri on cf.QuoteRunID = qri.ID
		and cf.cashflowDate >= qri.InflationDate

--===============================================================================
-- update discountFactors
--===============================================================================
update cf
set cf.discountFactor = power(1+fyc.AnnualEffectiveSpotYield,-cf.[Maturity(months)]/12.0)
from
	#cashflows cf
	inner join ParameterTables.FittedYieldCurves fyc on fyc.[Maturity(months)] = cf.[Maturity(months)]
	inner join #runinfo ri on ri.YieldCurve = fyc.BondName

/* fill those where the cashflows are beyond the yield curve */
select
	top 1 fyc.*
into
	#longestMaturity
from
	ParameterTables.FittedYieldCurves fyc
	inner join #runinfo ri on ri.YieldCurve = fyc.BondName
order by
	[Maturity(months)] desc

update cf
set cf.discountFactor = power(1+lm.AnnualEffectiveSpotYield, -cf.[Maturity(months)]/12.0)
from
	#cashflows cf
	inner join #longestMaturity lm on 1 = 1
where
	cf.discountFactor is null

drop table #longestMaturity

--===============================================================================
-- update survival probabilities
--===============================================================================
-- get mortality table
select
	mt.Age, [MortalityRate(age)], [SurvivalRate(age)] = 1.0 - [MortalityRate(age)]
into
	#mortalityTable
from	
	#QuoteRunInfo qri
	inner join #runinfo ri on ri.Sex = qri.Sex
	inner join ParameterTables.MortalityTables mt on mt.TableName = ri.MortalityTable

-- get current age
select
	cf.Age, 
	SurvivalInMonth = 
		case 
			when ID = 1 then 1.0 
			else power([SurvivalRate(age)],1.0/12.0)
		end
into
	#fittedMortality
from
	#cashflows cf
	inner join #mortalityTable mt on mt.Age = floor(cf.Age)

drop table #mortalityTable

select
	fm.Age,
	CummulativeSurvivalProbability = sum(log(fm1.SurvivalInMonth))
into
	#cummulativeMortality
from
	#fittedMortality fm
	inner join #fittedMortality fm1 on fm1.Age <= fm.Age
group by
	fm.Age

drop table #fittedMortality

update #cummulativeMortality
set CummulativeSurvivalProbability = exp(CummulativeSurvivalProbability)

update cf
set cf.probabilityOfSurvival = cm.CummulativeSurvivalProbability
from
	#cashflows cf
	inner join #cummulativeMortality cm on cm.Age = cf.Age

drop table #cummulativeMortality

/* fill those survival probabilities beyond mortality table */

update #cashflows
set probabilityOfSurvival = 0
where
	probabilityOfSurvival is null

--===============================================================================
-- save result
--===============================================================================
insert into Quotes.QuoteRunCashflows
	(QuoteRunID, 
	RunID,
	cashflowDate, 
	[Maturity(months)], 
	Age, 
	Benefit, 
	inflationFactor, 
	discountFactor, 
	probabilityOfSurvival)
select
	QuoteRunID,
	RunID = @RunID,
	cashflowDate, 
	[Maturity(months)], 
	Age, 
	Benefit, 
	inflationFactor, 
	discountFactor, 
	probabilityOfSurvival
from
	#cashflows

insert into Quotes.QuoteRunResults
	(QuoteRunID,
	RunID,
	PresentValue,
	LifeExpectancy)
select
	QuoteRunID = @QuoteRunID,
	RunID = @RunID,
	PresentValue = sum(Benefit * inflationFactor * discountFactor * probabilityOfSurvival),
	LifeExpectancy = sum(1.0/12.0 * probabilityOfSurvival)
from
	#cashflows

drop table #cashflows
drop table #QuoteRunInfo
drop table #runinfo