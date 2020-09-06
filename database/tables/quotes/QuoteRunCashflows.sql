create table Quotes.QuoteRunCashflows
		(ID int identity, 
		QuoteRunID int,
		RunID int,
		cashflowDate date, 
		[Maturity(months)] int, 
		Age float, 
		Benefit money, 
		inflationFactor float, 
		discountFactor float, 
		probabilityOfSurvival float)