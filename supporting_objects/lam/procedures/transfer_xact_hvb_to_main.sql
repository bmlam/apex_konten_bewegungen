CREATE OR REPLACE PROCEDURE transfer_xact_hvb_to_main
(
    pi_bank_alias VARCHAR2
    ,pi_bank_code VARCHAR2
    ,pi_csv_version VARCHAR2 DEFAULT 'DE'
)
AS
    lc_module VARCHAR2(100);
    lc_date_mask VARCHAR2(20) := 'yyyy.mm.dd';

    l_max_xact_dt_tgt DATE;

    l_min_xact_dt_src DATE;
    l_max_xact_dt_src DATE;
    l_xact_dt_range_conflicts BOOLEAN;
BEGIN
    IF pi_csv_version NOT IN ( 'EN', 'DE') THEN
        RAISE_APPLICATION_ERROR( 20001, 'pi_csv_version '||substr(pi_csv_version, 1, 3)||' is invalid for '||lc_module );
    END IF;

    pck_std_log.info( a_comp=> $$plsql_unit, a_subcomp=>'Line'||$$plsql_line
            , a_text=> 'alias:'||pi_bank_alias
                || ' acc:'||pi_bank_code
        );

    /* assert earliest xact date in import table is after latest xact date in target */
    select max(booking_date)
    into l_max_xact_dt_tgt
    from bank_transaction
    where bank_alias = pi_bank_alias
      and account_no = pi_bank_code
    ;

    CASE pi_csv_version 
    WHEN 'DE'
    THEN 
        SELECT min( buchungsdatum), max(buchungsdatum)
        into l_min_xact_dt_src, l_max_xact_dt_src
        FROM    imp_hvb_csv_deutsch
        WHERE apex_sess_id = APEX_CUSTOM_AUTH.GET_SESSION_ID
        ;
    END CASE;

    l_xact_dt_range_conflicts := l_max_xact_dt_tgt BETWEEN l_min_xact_dt_src AND l_max_xact_dt_src 
            OR l_max_xact_dt_tgt > l_max_xact_dt_src
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
        END CASE; -- Language ok
        COMMIT;
    END CASE;

    CASE pi_csv_version 
    WHEN 'DE'
    THEN 
        DELETE FROM    imp_hvb_csv_deutsch
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

