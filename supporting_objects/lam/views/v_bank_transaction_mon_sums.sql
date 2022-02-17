CREATE OR REPLACE VIEW v_bank_transaction_mon_sums
AS
WITH add_dims_ AS (
	SELECT extract ( year from booking_date ) as xact_year
	    ,  extract ( month from booking_date ) as xact_month
	    ,  extract ( day from booking_date ) as xact_day
	    ,  booking_date, bank_alias, account_no
	    ,  bank_alias||'-'||account_no AS bank_and_acc 
	FROM bank_transaction
) , add_dims2_ AS (
    SELECT 
	  xact_year||'.'|| lpad( xact_month, 2, '0') AS yyyymm
      , add_dims_.*
    FROM add_dims_
) , agg1_ AS (
    SELECT 
        bank_and_acc, xact_year, xact_month, yyyymm
        , min( xact_day ) first_day	
        , max( xact_day ) last_day
        , count(1) items  
    FROM add_dims2_ 
    GROUP BY rollup(     bank_and_acc, xact_year, xact_month, yyyymm )
)
SELECT * 
FROM agg1_     
WHERE yyyymm IS NOT NULL
--ORDER BY xact_year, xact_month, bank_and_acc
;