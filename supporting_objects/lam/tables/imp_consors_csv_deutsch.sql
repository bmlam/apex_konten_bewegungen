CREATE TABLE  imp_consors_csv_deutsch 
   (	"Buchung" DATE, 
	"Valuta" DATE, 
	"Sender / Empfänger" VARCHAR2(100 CHAR), 
	"IBAN" VARCHAR2(50 CHAR), 
	"BIC" VARCHAR2(20 CHAR), 
	"Buchungstext" VARCHAR2(200 CHAR), 
	"Verwendungszweck" VARCHAR2(100 CHAR), 
	"Betrag" VARCHAR2(10 CHAR), 
	"Währung" VARCHAR2(3 CHAR), 
	"INSERT_DT" DATE DEFAULT sysdate, 
	"APEX_SESS_ID" NUMBER
   )
/
