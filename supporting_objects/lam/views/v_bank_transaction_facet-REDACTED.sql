CREATE OR REPLACE VIEW v_bank_transaction_facet_2
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
       "Soll",
        "Haben",
       debit,
       credit,
       currency,
       transaction_type,
       masked_data( payment_details ) AS payment_details,
       masked_data( iban_counterparty ) AS iban_counterparty,
       bic_counterparty,
       year_booking,
       month_booking,
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
       ,amount 
  FROM v_bank_transaction_facet_base 
/