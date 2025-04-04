CREATE OR REPLACE VIEW v_imp_consors_csv_de_2main_map
AS
WITH char_2_num AS (
	SELECT 
	    Buchung 			AS BOOKING_DATE
	   ,valuta         		AS value_date
	   ,Sender_Empfaenger   AS beneficiary_originator
	   ,Buchungstext		AS transaction_type
	   ,Verwendungszweck	AS payment_details
	   ,iban 
	   ,bic 
	   ,Waehrung			AS currency 
	   ,TO_NUMBER( betrag,  '999g999g999d99' ,q'[NLS_NUMERIC_CHARACTERS = ',.']' )   
	   	AS amount       
	   , insert_dt , apex_sess_id         
    FROM IMP_consors_CSV_DEUTSCH a
)
SELECT cn.*
	, CASE WHEN amount < 0 THEN amount END AS debit
	, CASE WHEN amount > 0 THEN amount END AS credit
FROM char_2_num cn 
/
