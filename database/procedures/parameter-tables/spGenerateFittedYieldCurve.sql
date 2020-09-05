alter proc ParameterTables.spGenerateFittedYieldCurve (@BondName varchar(200), @CaptureDate date)
as
select
	Rank = ROW_NUMBER() over (order by [Maturity(months)]),
	[Maturity(months)],
	[SpotYield],
	PreviousMaturity = cast(null as int),
	PreviousSpotYield = cast(null as float),
	MaturityDiff = cast(null as int),
	MonthlyEffectiveForwardYield = cast(null as float)
into
	#yieldCurveToFit
from
	ParameterTables.YieldCurves
where
	BondName = @BondName
	and CaptureDate = @CaptureDate

update t
set 
	t.PreviousMaturity = isnull(t1.[Maturity(months)],0), 
	t.PreviousSpotYield = isnull(t1.SpotYield,0)
from
	#yieldCurveToFit t
	left join #yieldCurveToFit t1 on t.Rank = t1.Rank+1

update #yieldCurveToFit
set MaturityDiff = [Maturity(months)] - PreviousMaturity

-- now calculate the MonthlyEffectiveForwardYieldRate
/*
This is calculated by calculating the accumulation factor between the two periods and then breaking it down into a monthly effective rate.
*/
update #yieldCurveToFit
set MonthlyEffectiveForwardYield = POWER(
									POWER(1.0+SpotYield,[Maturity(months)]/12.0)
									/power(1.0+PreviousSpotYield,[PreviousMaturity]/12.0)
									,1.0/MaturityDiff)
									- 1.0

-- now calculate the fittedYieldCurve
/*
This is calculated by assuming that the forward rates are flat between points.
*/
create table #fittedYieldCurve
	([Maturity(months)] int,
	MonthlyEffectiveForwardYield float,
	AccumulationFactor float,
	[AnnualEffectiveSpotYield] float)

insert into #fittedYieldCurve
values (0,0,1,0)

declare @startMonth int = 1, @endMonth int = 360
while @startMonth <= @endMonth
begin
	insert into #fittedYieldCurve ([Maturity(months)])
	select @startMonth
	set @startMonth = @startMonth + 1
end

update fyc
set fyc.MonthlyEffectiveForwardYield = t.MonthlyEffectiveForwardYield
from
	#fittedYieldCurve fyc
	inner join #yieldCurveToFit t on fyc.[Maturity(months)] <= t.[Maturity(months)] 
where
	fyc.[Maturity(months)] <> 0

drop table #yieldCurveToFit

select
	fyc.[Maturity(months)],
	AccumulationFactor = sum(log(1+fyc1.MonthlyEffectiveForwardYield))
into
	#accumulationStep
from
	#fittedYieldCurve fyc
	inner join #fittedYieldCurve fyc1 on fyc1.[Maturity(months)] <= fyc.[Maturity(months)]
group by
	fyc.[Maturity(months)]

update #accumulationStep
set
	AccumulationFactor = power(exp(AccumulationFactor),12.0/[Maturity(months)])
where
	[Maturity(months)] <> 0

update fyc
set fyc.AccumulationFactor = accS.AccumulationFactor
from
	#fittedYieldCurve fyc
	inner join #accumulationStep accS on fyc.[Maturity(months)] = accS.[Maturity(months)]

drop table #accumulationStep

update #fittedYieldCurve
set AnnualEffectiveSpotYield = AccumulationFactor - 1
where
	[Maturity(months)] <> 0 

-- insert the fitted curve
insert into ParameterTables.FittedYieldCurves
	(BondName,
	CaptureDate,
	[Maturity(months)],
	[MonthlyForwardRate],
	[AnnualEffectiveSpotYield])
select
	@BondName,
	@CaptureDate,
	[Maturity(months)],
	[MonthlyForwardRate] = MonthlyEffectiveForwardYield,
	AnnualEffectiveSpotYield
from
	#fittedYieldCurve

drop table #fittedYieldCurve