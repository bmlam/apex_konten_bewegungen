create or replace trigger imp_hvb_csv_deutsch_trg1
BEFORE
insert or update or delete on imp_hvb_csv_deutsch
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