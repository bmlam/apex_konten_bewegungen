CREATE OR REPLACE VIEW v_bank_transaction_facet
AS
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
       payment_details,
       iban_counterparty,
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