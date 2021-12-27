create or replace trigger IMP_DEUTSCHE_BANK_TRG1
BEFORE
insert or update or delete on IMP_DEUTSCHE_BANK
for each row
begin
  CASE 
  WHEN INSERTING 
  THEN 
    IF :new.apex_sess_id IS NULL 
    THEN
      :new.apex_sess_id := coalesce (APEX_CUSTOM_AUTH.GET_SESSION_ID, -1);
    END IF;
  ELSE
    NULL;
  END CASE;
end;
/

show error