CREATE OR REPLACE PROCEDURE transfer_xact_hvb_to_main
(
    pi_bank_alias VARCHAR2
    ,pi_bank_code VARCHAR2
    ,pi_csv_version VARCHAR2 DEFAULT 'DE'
)
AS
BEGIN 
    pkg_kto_bwg.transfer_xact_hvb_to_main
    (
        pi_bank_alias => pi_bank_alias
        ,pi_bank_code => pi_bank_code
        ,pi_csv_version => pi_csv_version
    );

END;
/


show error

