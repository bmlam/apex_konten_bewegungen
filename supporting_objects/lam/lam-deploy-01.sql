
DEFINE base_path=&&1 

col object_name format a40
col object_type format a20
col systimestamp formnat a30 
col db_name formnat a30 

spool lam-deploy-01.log 

SET LINESize 120 pagesize 100 

SELECT systimestamp, user, sys_context( 'userenv', 'db_name') db_name 
FROM dual
;

PROMPT show invalid objects before deployment 

SELECT object_name, object_type, status
FROM user_objects
WHERE status <> 'VALID'
;

PROMPT Tables 
start &base_path/tables/app_action_audit.sql
start &base_path/tables/bank_account.sql
start &base_path/tables/bank_transaction.sql
start &base_path/tables/imp_deutsche_bank.sql
start &base_path/tables/imp_hvb_csv_deutsch.sql
start &base_path/tables/imp_deutsche_bank_csv_deutsch.sql
start &base_path/tables/imp_deutsche_bank_legacy.sql

PROMPT Table Triggers
start &base_path/tables/imp_deutsche_bank_csv_deutsch_t1.sql
start &base_path/tables/imp_deutsche_bank_trg1.sql
start &base_path/tables/imp_hvb_csv_deutsch_trg1.sql


PROMPT Views 
start &base_path/views/v_bank_account_lovs.sql
start &base_path/views/v_bank_transaction_facet.sql

PROMPT Functions 

PROMPT Package specifications
start &base_path/packages/pkg_kto_bwg-def.sql

PROMPT Package bodies
start &base_path/packages/pkg_kto_bwg-impl.sql

PROMPT Procedures  
start &base_path/procedures/transfer_xact_hvb_to_main.sql
start &base_path/procedures/transfer_xact_deu_bank_to_main.sql

begin dbms_utility.compile_schema ( 'LAM', compile_all => FALSE);
end;
/

PROMPT show invalid objects after deployment 

SELECT object_name, object_type, status
FROM user_objects
WHERE status <> 'VALID'
;

spool off

