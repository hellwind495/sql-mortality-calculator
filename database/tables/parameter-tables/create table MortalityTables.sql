create table ParameterTables.MortalityTables 
	(ID int identity,
	TableName varchar(50),
	Age int, 
	Sex varchar(10), 
	[MortalityForce(age+1/2)] float, 
	[MortalityRate(age)] float)
