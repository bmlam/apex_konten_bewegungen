CREATE OR REPLACE VIEW v_bank_account_lovs
AS
SELECT account_code account_id , bank_alias bank_code , bank_alias||': '||account_code||' '||substr( comments, 1, 50) as lov_description 
FROM bank_account 
/