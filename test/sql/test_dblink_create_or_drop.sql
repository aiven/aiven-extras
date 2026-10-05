CREATE EXTENSION aiven_extras;
-- dblink (and Aiven's patched dblink also for superusers) requires a password
-- that the server actually asks for: use a TCP connection with a password role.
CREATE ROLE regress_aiven_extras_dblink LOGIN REPLICATION PASSWORD 'regress_aiven_extras_pw';
\set connstr 'host=127.0.0.1 user=regress_aiven_extras_dblink password=regress_aiven_extras_pw'
SELECT aiven_extras.dblink_slot_create_or_drop(format('%s dbname=%I port=%s', :'connstr', current_database(), current_setting('port')), 'test_slot', 'create');
SELECT slot_name from pg_replication_slots where slot_name = 'test_slot';
SELECT aiven_extras.dblink_slot_create_or_drop(format('%s dbname=%I port=%s', :'connstr', current_database(), current_setting('port')), 'test_slot', 'drop');
SELECT slot_name from pg_replication_slots where slot_name = 'test_slot';
DROP ROLE regress_aiven_extras_dblink;
