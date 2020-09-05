create table Quotes.QuoteRuns
	(ID int identity,
	API varchar(200),
	CustomerName varchar(1000),
	DateOfBirth date,
	DateOfRetirement date,
	Sex varchar(10),
	Benefit money,
	AnnualInflation float,
	InflationDate date)