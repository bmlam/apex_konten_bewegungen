CREATE OR REPLACE VIEW v_bank_transaction_facet_base 
AS
SELECT id, 
       bank_alias,
       account_no,
       booking_date,       value_date,
       CASE WHEN debit IS NOT NULL THEN '-' ||to_char( abs(debit) , '9G999G999G999D00') END "Soll",
       to_char( credit    , '9G999G999G999D00') "Haben",
       debit,
       credit,
       currency,
       transaction_type,
       payment_details,
       iban iban_counterparty,
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
       , coalesce( credit, debit) amount 
  FROM bank_transaction 
/