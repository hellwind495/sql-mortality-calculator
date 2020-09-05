create table ParameterTables.FittedYieldCurves
	(ID int identity,
	BondName varchar(200),
	CaptureDate date,
	[Maturity(months)] int,
	[MonthlyForwardRate] float,
	[AnnualEffectiveSpotYield] float)