alter proc Quotes.spGenerateCashflowsOnCurrentRun @QuoteRunID int
as
declare @RunID int = (select top 1 RunID from config.CurrentRun)
exec Quotes.spGenerateCashflows @QuoteRunID, @RunID