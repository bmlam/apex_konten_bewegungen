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
       CASE bank_alias WHEN 'DB.COM' THEN '24242424' WHEN 'HVB' THEN '999333666' END AS account_no,
       booking_date,       value_date,
       "Soll",
        "Haben",
       debit,
       credit,
       currency,
       transaction_type,
       substr( masked_data( payment_details ) , 1, 100) AS payment_details,
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