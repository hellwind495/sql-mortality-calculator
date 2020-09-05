create table ParameterTables.YieldCurves
	(ID int identity,
	BondName varchar(200),
	CaptureDate date,
	[Maturity(months)] int,
	SpotYield float)