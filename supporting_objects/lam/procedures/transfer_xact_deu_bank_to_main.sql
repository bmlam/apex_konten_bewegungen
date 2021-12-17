CREATE OR REPLACE PROCEDURE transfer_xact_deu_bank_to_main
(
    pi_bank_alias VARCHAR2
    ,pi_bank_code VARCHAR2
    ,pi_csv_version VARCHAR2 DEFAULT 'EN'
)
AS
    lc_module VARCHAR2(100);
    lc_date_mask VARCHAR2(20) := 'yyyy.mm.dd';

    l_max_xact_dt_tgt DATE;

    l_min_xact_dt_src DATE;
    l_max_xact_dt_src DATE;
    l_xact_dt_range_conflicts BOOLEAN;
    l_bank_alias_used bank_transaction.bank_alias%TYPE;
BEGIN
    IF pi_csv_version NOT IN ( 'EN', 'DE') THEN
        RAISE_APPLICATION_ERROR( 20001, 'pi_csv_version '||substr(pi_csv_version, 1, 3)||' is invalid for '||lc_module );
    END IF;

    pck_std_log.info( a_comp=> $$plsql_unit, a_subcomp=>'Line'||$$plsql_line
            , a_text=> 'alias:'||pi_bank_alias
                || ' acc:'||pi_bank_code
                || ' lang:'||pi_csv_version 
        );
    l_bank_alias_used := pi_bank_alias;
    IF nvl(pi_bank_alias, '?') = '?' AND pi_bank_code IS NOT NULL 
    THEN
        SELECT bank_code 
        INTO  l_bank_alias_used 
        FROM v_bank_account_lovs
        WHERE account_id = pi_bank_code
        ;
    END IF;
   --apex_debug.enable( 6 );
    --apex_debug.enter( $$plsql_unit, 'bank_alias', pi_bank_alias, 'bank_code', pi_bank_code);
    /* assert earliest xact date in import table is after latest xact date in target */
    select max(booking_date)
    into l_max_xact_dt_tgt
    from bank_transaction
    where bank_alias = l_bank_alias_used
      and account_no = pi_bank_code
    ;

    CASE pi_csv_version 
    WHEN 'EN' 
    THEN 
        select min(booking_date), max(booking_date)
        into l_min_xact_dt_src, l_max_xact_dt_src
        from imp_deutsche_bank
        --WHERE apex_sess_id = APEX_CUSTOM_AUTH.GET_SESSION_ID
        ;
    WHEN 'DE'
    THEN 
        SELECT min( buchungstag), max(buchungstag)
        into l_min_xact_dt_src, l_max_xact_dt_src
        FROM    IMP_DEUTSCHE_BANK_CSV_DEUTSCH
        WHERE apex_sess_id = APEX_CUSTOM_AUTH.GET_SESSION_ID
        ;
    END CASE;

    l_xact_dt_range_conflicts := l_max_xact_dt_tgt BETWEEN l_min_xact_dt_src AND l_max_xact_dt_src 
        OR l_max_xact_dt_tgt >  l_max_xact_dt_src 
        ;

    pck_std_log.info( a_comp=> $$plsql_unit, a_subcomp=>'Line'||$$plsql_line
            , a_text=> ' l_max_xact_dt_tgt:'|| to_char( l_max_xact_dt_tgt, lc_date_mask )
                || ' l_min_xact_dt_src:'|| to_char( l_min_xact_dt_src, lc_date_mask )
                || ' l_max_xact_dt_src:'|| to_char( l_max_xact_dt_src, lc_date_mask )
                || ' date_range_conflict: "'|| sys.diutil.bool_to_int (l_xact_dt_range_conflicts) ||'"'
        );

    CASE 
    WHEN l_xact_dt_range_conflicts 
    THEN 
        RAISE_APPLICATION_ERROR( -20001,  
            'transactions upto :'|| to_char(l_max_xact_dt_tgt, lc_date_mask )
                || ' already exist for target account while trying to load new transaction from :'
                || to_char(l_min_xact_dt_src , lc_date_mask ) );
    WHEN l_min_xact_dt_src IS NULL 
    THEN 
        RAISE_APPLICATION_ERROR( -20001, 'source data must have a booking date!');
    WHEN l_max_xact_dt_tgt IS NULL -- target table empty 
        OR NOT l_xact_dt_range_conflicts 
    THEN 
        --pck_std_log.info( a_comp=> $$plsql_unit, a_subcomp=>'Line'||$$plsql_line   , a_text=> ' got here');
        CASE pi_csv_version
        WHEN 'EN'
        THEN 
            INSERT INTO bank_transaction
            (   BOOKING_DATE,            VALUE_DATE,            TRANSACTION_TYPE,            BENEFICIARY_ORIGINATOR,            PAYMENT_DETAILS,
            IBAN,            BIC,            CUSTOMER_REFERENCE,            MANDATE_REFERENCE,            CREDITOR_ID,
            COMPENSATION_AMOUNT,            ORIGINAL_AMOUNT,            ULTIMATE_CREDITOR,            NUMBER_OF_TRANSACTIONS,            NUMBER_OF_CHEQUES,
            DEBIT,            CREDIT,            CURRENCY,            BANK_ALIAS,            ACCOUNT_NO
            )
            SELECT  BOOKING_DATE,            VALUE_DATE,            TRANSACTION_TYPE,            BENEFICIARY___ORIGINATOR,            PAYMENT_DETAILS,
            IBAN,            BIC,            CUSTOMER_REFERENCE,            MANDATE_REFERENCE,            CREDITOR_ID,
            COMPENSATION_AMOUNT,            ORIGINAL_AMOUNT,            ULTIMATE_CREDITOR,            NUMBER_OF_TRANSACTIONS,            NUMBER_OF_CHEQUES,
            DEBIT,            CREDIT,            CURRENCY,            l_bank_alias_used ,            pi_bank_code
            from IMP_DEUTSCHE_BANK s
            ;

        WHEN 'DE'
        THEN 
            INSERT INTO bank_transaction
            (   BOOKING_DATE,            VALUE_DATE,            TRANSACTION_TYPE,            BENEFICIARY_ORIGINATOR,            PAYMENT_DETAILS,
            IBAN,            BIC,            CUSTOMER_REFERENCE,            MANDATE_REFERENCE,            CREDITOR_ID,
            COMPENSATION_AMOUNT,            ORIGINAL_AMOUNT,            ULTIMATE_CREDITOR,            NUMBER_OF_TRANSACTIONS,            NUMBER_OF_CHEQUES,
            DEBIT,            
            CREDIT,            
            CURRENCY,            BANK_ALIAS,            ACCOUNT_NO
            )
            select 
                BUCHUNGSTAG,                WERT,                UMSATZART,                "BEGÜNSTIGTER___AUFTRAGGEBER",                VERWENDUNGSZWECK,
                IBAN,                BIC,                KUNDENREFERENZ,                MANDATSREFERENZ,                "GLÄUBIGER_ID",
                "FREMDE_GEBÜHREN",                BETRAG,                "ABWEICHENDER_EMPFÄNGER",                "ANZAHL_DER_AUFTRÄGE",                ANZAHL_DER_SCHECKS,
                TO_NUMBER( soll,  '999g999g999d99' ,q'[NLS_NUMERIC_CHARACTERS = ',.']' )   SOLL,               
                TO_NUMBER( haben, '999g999g999d99' ,q'[NLS_NUMERIC_CHARACTERS = ',.']' )   HABEN,               
                "WÄHRUNG",            l_bank_alias_used ,            pi_bank_code
            from IMP_DEUTSCHE_BANK_CSV_DEUTSCH a
            WHERE apex_sess_id = APEX_CUSTOM_AUTH.GET_SESSION_ID
            ;
        END CASE; -- Language ok
        COMMIT;
    END CASE;

    CASE pi_csv_version 
    WHEN 'EN' 
    THEN 
        DELETE from imp_deutsche_bank
        --WHERE apex_sess_id = APEX_CUSTOM_AUTH.GET_SESSION_ID
        ;
    WHEN 'DE'
    THEN 
        DELETE FROM    IMP_DEUTSCHE_BANK_CSV_DEUTSCH
        WHERE apex_sess_id = APEX_CUSTOM_AUTH.GET_SESSION_ID
        ;
    END CASE;
    COMMIT;
EXCEPTION 
    WHEN OTHERS THEN 
        pck_std_log.error( a_err_code=> sqlcode, a_comp=> $$plsql_unit, a_subcomp=>'Line'||$$plsql_line, a_text=> sqlerrm);
        RAISE;
END;
/


show error

