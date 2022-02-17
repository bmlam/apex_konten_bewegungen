CREATE OR REPLACE VIEW v_bank_transaction_facet
AS
WITH FUNCTION masked_data 
       ( pi_data VARCHAR2
       )      
       RETURN VARCHAR2 AS 
       BEGIN 
              RETURN 
                     translate ( pi_data, 'aeiouAEIOUcfhkmprtwzCFHKMPRTWZ02468'
                                          ,'xxxxxxxxxxxxxxxxxxxxxxxxxxxxx99999'
                            );
       END masked_data;
SELECT id, 
       bank_alias,
       account_no,
       booking_date,       value_date,
       to_char( debit * -1, '9G999G999G999D00') "Soll",
       to_char( credit    , '9G999G999G999D00') "Haben",
       debit,
       credit,
       currency,
       transaction_type,
       masked_data( payment_details ) AS payment_details,
       masked_data( iban ) AS iban_counterparty,
       bic  bic_counterparty,
       extract( year from booking_date) as year_booking,
       extract( month from booking_date) as month_booking,
       beneficiary_originator,
       customer_reference,
       mandate_reference,
       creditor_id,
       compensation_amount,
       original_amount,
       ultimate_creditor,
       number_of_transactions,
       number_of_cheques,
       load_dt
       , CASE WHEN debit IS NOT NULL THEN debit ELSE credit END amount 
  FROM bank_transaction 
/