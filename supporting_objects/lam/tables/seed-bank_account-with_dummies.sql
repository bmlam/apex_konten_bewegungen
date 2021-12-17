CREATE TABLE  "BANK_ACCOUNT" 
   (	"BANK_ALIAS" VARCHAR2(20 CHAR) NOT NULL ENABLE, 
	"ACCOUNT_CODE" VARCHAR2(30 CHAR) NOT NULL ENABLE, 
	"COMMENTS" VARCHAR2(300 CHAR), 
	 CHECK ( trim( upper(account_code) )= account_code ) ENABLE, 
	 UNIQUE ("ACCOUNT_CODE")
  USING INDEX  ENABLE
   )
/

INSERT INTO bank_account ( bank_alias, account_code, comments )
VALUES ( upper('Deutsche_Bank'), upper('deutsche_bank_iban'), 'dummy iban')
;

INSERT INTO bank_account ( bank_alias, account_code, comments )
VALUES ( upper('Hvb'), upper('Hvb_iban'), 'dummy iban')
;

commit;
