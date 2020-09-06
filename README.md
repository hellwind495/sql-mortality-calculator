# Mortality calculator
This is a basic project setting out an annuity factor calculator built using SQL code.

## Basics
This uses South African Annuitant Standard Mortality Tables derived by RD Dorrington and S Tootla. The paper where this can be found was published in the South African Actuarial Journal and can be found here: 
[SOUTH AFRICAN ANNUITANT STANDARD MORTALITY TABLES 1996–2000(SAIML98 and SAIFL98)](https://www.actuarialsociety.org.za/download/south-african-annuitant-standard-mortality-tables/)

The yield curve was retrieved from [yield curve](http://www.worldgovernmentbonds.com/country/south-africa/) on 5th September 2020.

## Calculation
The heavy calculation happens in [Quotes.spGenerateCashflows](database/procedures/quotes/spGenerateCashflows.sql).

A cashflow calculation is used to transform the data in Quotes.QuoteRuns into a cashflow table in Quotes.QuoteRunCashlows and finally results in Quotes.QuoteRunResults.

Discounting, allowing for probability of survival and inflation are done in this procedure.

## Additional calculations
Additionally, different maturities are needed for the yield curve. This fitting is handled in [ParameterTables.spGenerateFittedYieldCurve](database/procedures/parameter-tables/spGenerateFittedYieldCurve.sql).