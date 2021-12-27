CREATE OR REPLACE PACKAGE BODY pkg_kto_bwg
AS
  gc_pkg_name user_objects.object_name%TYPE := $$plsql_unit; 
  gc_date_mask VARCHAR2(20) := 'yyyy.mm.dd';

  PROCEDURE audit_action 
  ( pi_action_key VARCHAR2
   ,pi_additional_info VARCHAR2
  ) AS 
  BEGIN
   INSERT INTO app_action_audit 
    ( login_user
      ,app_key
      ,action_key
      ,additional_info
    ) VALUES 
    ( COALESCE ( v('APP_USER')
                , sys_context('userenv', 'current_user')||':'||sys_context('userenv', 'os_user') )
      , COALESCE( V('APP_NAME'), gc_pkg_name )
      , pi_action_key 
      , pi_additional_info
    );
  END audit_action;

  PROCEDURE check_conflict_with_target
  ( pi_bank_alias VARCHAR2 
   ,pi_account_no VARCHAR2 
   ,pi_period_begin DATE 
   ,pi_period_end   DATE
   ,po_conflict_count OUT NUMBER 
  ) AS 
  BEGIN 
    select COUNT(1)
    into po_conflict_count
    from bank_transaction
    where bank_alias = pi_bank_alias
      and account_no = pi_account_no
      AND booking_date BETWEEN pi_period_begin AND pi_period_end
    ;
  END check_conflict_with_target;

  PROCEDURE delete_scoped_transaction
  ( p_period_begin DATE
   ,p_period_end   DATE 
   ,p_account_no   VARCHAR2
   ,p_autocommit   BOOLEAN DEFAULT TRUE 
  	)
  AS 
    l_sql_rowcount NUMBER; 
  BEGIN 
    pck_std_log.info( a_comp=> $$plsql_unit, a_subcomp=>'Line'||$$plsql_line
            , a_text=> ' period begin:'|| to_char( p_period_begin, gc_date_mask )
                || ' end:'|| to_char( p_period_end, gc_date_mask )
                || ' accountno:'|| p_account_no
        );

    DELETE bank_transaction
    WHERE p_account_no = account_no 
    ;
    l_sql_rowcount := SQL%ROWCOUNT;

    audit_action 
    ( pi_action_key => 'DELETE_SCOPED_TRANSACTION'
     ,pi_additional_info => 'Rows: '||l_sql_rowcount
    );  
 
    IF p_autocommit THEN 
      COMMIT;
    END IF; 

  EXCEPTION 
    WHEN OTHERS THEN 
      pck_std_log.error( a_err_code=> sqlcode, a_text=> sqlerrm, a_comp=> gc_pkg_name );
      IF p_autocommit THEN 
        ROLLBACK;
      END IF;
      RAISE;
END delete_scoped_transaction;

/*********************************************************************************/

PROCEDURE transfer_xact_hvb_to_main
(    pi_bank_alias VARCHAR2
    ,pi_bank_code VARCHAR2
    ,pi_csv_version VARCHAR2 DEFAULT 'DE'
   ,p_autocommit   BOOLEAN DEFAULT TRUE 
)
AS
    lc_module VARCHAR2(100);

    l_in_same_period_count NUMBER;

    l_min_xact_dt_src DATE;
    l_max_xact_dt_src DATE;
    l_xact_dt_range_conflicts BOOLEAN;
    l_sql_rowcount NUMBER;
BEGIN
    IF pi_csv_version NOT IN ( 'EN', 'DE') THEN
        RAISE_APPLICATION_ERROR( 20001, 'pi_csv_version '||substr(pi_csv_version, 1, 3)||' is invalid for '||lc_module );
    END IF;

    pck_std_log.info( a_comp=> $$plsql_unit, a_subcomp=>'Line'||$$plsql_line
            , a_text=> 'alias:'||pi_bank_alias
                || ' acc:'||pi_bank_code
        );

    CASE pi_csv_version 
    WHEN 'DE'
    THEN 
        SELECT min( buchungsdatum), max(buchungsdatum)
        into l_min_xact_dt_src, l_max_xact_dt_src
        FROM    imp_hvb_csv_deutsch
        WHERE apex_sess_id = APEX_CUSTOM_AUTH.GET_SESSION_ID
        ;
    END CASE;

    check_conflict_with_target  
      ( pi_bank_alias => pi_bank_alias 
       ,pi_account_no => pi_bank_code  
       ,pi_period_begin => l_min_xact_dt_src 
       ,pi_period_end   => l_max_xact_dt_src
       ,po_conflict_count => l_in_same_period_count 
    ); 

    l_xact_dt_range_conflicts := l_in_same_period_count > 0;

     pck_std_log.info( a_comp=> $$plsql_unit, a_subcomp=>'Line'||$$plsql_line
            , a_text=> ' l_min_xact_dt_src:'|| to_char( l_min_xact_dt_src, gc_date_mask )
                || ' l_max_xact_dt_src:'|| to_char( l_max_xact_dt_src, gc_date_mask )
                || ' l_in_same_period_count: '|| l_in_same_period_count 
        );
   
    CASE 
    WHEN l_xact_dt_range_conflicts THEN 
        RAISE_APPLICATION_ERROR( -20001,  
            'Mindestens '||l_in_same_period_count||' Eintraege in der Period :'
              || to_char(l_min_xact_dt_src, gc_date_mask )
              || ' bis '
              || to_char(l_min_xact_dt_src , gc_date_mask ) 
              ||' existieren bereits für das gleiche Konto!'
              );
    WHEN l_min_xact_dt_src IS NULL  THEN 
        RAISE_APPLICATION_ERROR( -20001, 'Die zu importierenden Daten haben anscheinend kein buchungsdatum!');
    WHEN NOT l_xact_dt_range_conflicts 
    THEN 
        --pck_std_log.info( a_comp=> $$plsql_unit, a_subcomp=>'Line'||$$plsql_line   , a_text=> ' got here');
        CASE pi_csv_version
        WHEN 'DE'
        THEN 
            INSERT INTO bank_transaction
            (   BOOKING_DATE,            VALUE_DATE,                 PAYMENT_DETAILS
             , DEBIT,            CREDIT,            CURRENCY,            BANK_ALIAS,            ACCOUNT_NO
            )
            WITH transform1_  AS  (   
                SELECT to_number( betrag, '999G999G999D99', ' NLS_NUMERIC_CHARACTERS = '',.'' ') AS betrag
                    ,buchungsdatum,                valuta,                 VERWENDUNGSZWECK
                    ,waehrung
                  FROM imp_hvb_csv_deutsch a
                  WHERE apex_sess_id = APEX_CUSTOM_AUTH.GET_SESSION_ID
                ) , imp_ AS (
              SELECT
                 CASE WHEN  betrag  <  0 THEN abs( betrag ) END as soll
                ,CASE WHEN  betrag  >= 0 THEN abs( betrag ) END as haben
                , a.*
              FROM transform1_ a
            )
            select 
                buchungsdatum,                valuta,                 VERWENDUNGSZWECK,
                SOLL,                HABEN,              waehrung,            pi_bank_alias ,            pi_bank_code
            FROM imp_
            ;
            l_sql_rowcount := SQL%ROWCOUNT;
        END CASE; -- Language ok

        audit_action 
        ( pi_action_key => UPPER('transfer_xact_hvb_to_main:'||pi_csv_version)
         ,pi_additional_info => 'Rows: '||l_sql_rowcount
        );  

    END CASE;

    CASE pi_csv_version 
    WHEN 'DE'
    THEN 
        DELETE FROM    imp_hvb_csv_deutsch
        WHERE apex_sess_id = APEX_CUSTOM_AUTH.GET_SESSION_ID
        ;
    END CASE;
    IF p_autocommit THEN 
      COMMIT;
    END IF;
EXCEPTION 
    WHEN OTHERS THEN 
      pck_std_log.error( a_err_code=> sqlcode, a_comp=> $$plsql_unit, a_subcomp=>'Line'||$$plsql_line, a_text=> sqlerrm);
      IF p_autocommit THEN 
        ROLLBACK;
      END IF;
        RAISE;
END transfer_xact_hvb_to_main;

/*********************************************************************************/

PROCEDURE transfer_xact_deu_bank_to_main
(
    pi_bank_alias VARCHAR2
    ,pi_bank_code VARCHAR2
    ,pi_csv_version VARCHAR2 DEFAULT 'EN'
    ,p_autocommit  BOOLEAN DEFAULT TRUE 
)
AS
    l_in_same_period_count NUMBER;
    l_min_xact_dt_src DATE;
    l_max_xact_dt_src DATE;
    l_xact_dt_range_conflicts BOOLEAN;
    l_bank_alias_used bank_transaction.bank_alias%TYPE;
BEGIN
    IF pi_csv_version NOT IN ( 'EN', 'DE') THEN
        RAISE_APPLICATION_ERROR( 20001, 'pi_csv_version '||substr(pi_csv_version, 1, 3)||' is invalid for procedure in '||gc_pkg_name||':ln'||$$plsql_line );
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

    /* compute period of transaction we are going to insert into the target table
    and make sure no single transaction within this period exists in the target
    This is to avoid duplicate data.
     */
    CASE pi_csv_version 
    WHEN 'EN' 
    THEN 
        select min(booking_date), max(booking_date)
        into l_min_xact_dt_src, l_max_xact_dt_src
        from imp_deutsche_bank
        WHERE apex_sess_id = APEX_CUSTOM_AUTH.GET_SESSION_ID
        ;
    WHEN 'DE'
    THEN 
        SELECT min( buchungstag), max(buchungstag)
        into l_min_xact_dt_src, l_max_xact_dt_src
        FROM    IMP_DEUTSCHE_BANK_CSV_DEUTSCH
        WHERE apex_sess_id = APEX_CUSTOM_AUTH.GET_SESSION_ID
        ;
    END CASE;

    check_conflict_with_target  
      ( pi_bank_alias => l_bank_alias_used 
       ,pi_account_no => pi_bank_code  
       ,pi_period_begin => l_min_xact_dt_src 
       ,pi_period_end   => l_max_xact_dt_src
       ,po_conflict_count => l_in_same_period_count 
    ); 
    l_xact_dt_range_conflicts := l_in_same_period_count = 0 
        ;

    pck_std_log.info( a_comp=> $$plsql_unit, a_subcomp=>'Line'||$$plsql_line
            , a_text=> ' l_min_xact_dt_src:'|| to_char( l_min_xact_dt_src, gc_date_mask )
                || ' l_max_xact_dt_src:'|| to_char( l_max_xact_dt_src, gc_date_mask )
                || ' l_in_same_period_count: '|| l_in_same_period_count 
        );

    CASE 
    WHEN l_xact_dt_range_conflicts 
    THEN 
        RAISE_APPLICATION_ERROR( -20001,  
            'Mindestens '||l_in_same_period_count||' Eintraege in der Period :'
              || to_char(l_min_xact_dt_src, gc_date_mask )
              || ' bis '
              || to_char(l_min_xact_dt_src , gc_date_mask ) 
              ||' existieren bereits für das gleiche Konto!'
              );
    WHEN l_min_xact_dt_src IS NULL 
    THEN 
        RAISE_APPLICATION_ERROR( -20001, 'Die zu importierenden Daten haben anscheinend kein buchungsdatum!');
    WHEN NOT l_xact_dt_range_conflicts 
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
    END CASE;

    CASE pi_csv_version 
    WHEN 'EN' 
    THEN 
        DELETE from imp_deutsche_bank
        WHERE apex_sess_id = APEX_CUSTOM_AUTH.GET_SESSION_ID
        ;
    WHEN 'DE'
    THEN 
        DELETE FROM    IMP_DEUTSCHE_BANK_CSV_DEUTSCH
        WHERE apex_sess_id = APEX_CUSTOM_AUTH.GET_SESSION_ID
        ;
    END CASE;

    IF p_autocommit THEN 
      COMMIT;
    END IF;
EXCEPTION 
    WHEN OTHERS THEN 
      pck_std_log.error( a_err_code=> sqlcode, a_comp=> $$plsql_unit, a_subcomp=>'Line'||$$plsql_line, a_text=> sqlerrm);
      IF p_autocommit THEN 
        ROLLBACK;
      END IF;
      RAISE;
END transfer_xact_deu_bank_to_main;
END;
/
show errors 