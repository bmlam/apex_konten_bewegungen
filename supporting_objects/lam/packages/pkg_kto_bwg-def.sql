CREATE OR REPLACE PACKAGE pkg_kto_bwg
AS
  PROCEDURE delete_scoped_transaction
  ( p_period_begin DATE
   ,p_period_end   DATE 
   ,p_account_no   VARCHAR2
   ,p_autocommit   BOOLEAN DEFAULT TRUE 
  );
  --
  PROCEDURE transfer_xact_hvb_to_main
  (
    pi_bank_alias VARCHAR2
    ,pi_bank_code VARCHAR2
    ,pi_csv_version VARCHAR2 DEFAULT 'DE'
    ,p_autocommit  BOOLEAN DEFAULT TRUE 
  );
--
PROCEDURE transfer_xact_deu_bank_to_main
(
    pi_bank_alias VARCHAR2
    ,pi_bank_code VARCHAR2
    ,pi_csv_version VARCHAR2 DEFAULT 'EN'
    ,p_autocommit  BOOLEAN DEFAULT TRUE 
);
--
PROCEDURE transfer_xact_consors_to_main
(
    pi_bank_alias VARCHAR2
    ,pi_bank_code VARCHAR2
    ,pi_csv_version VARCHAR2 DEFAULT 'DE'
    ,p_autocommit  BOOLEAN DEFAULT TRUE 
);
--
END;
/
show errors 