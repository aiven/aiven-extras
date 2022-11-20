CREATE EXTENSION aiven_extras;
SELECT aiven_extras.dblink_slot_create_or_drop(format('dbname=%I port=%s', current_database(), current_setting('port')), 'test_slot', 'create');
SELECT slot_name from pg_replication_slots where slot_name = 'test_slot';
SELECT aiven_extras.dblink_slot_create_or_drop(format('dbname=%I port=%s', current_database(), current_setting('port')), 'test_slot', 'drop');
SELECT slot_name from pg_replication_slots where slot_name = 'test_slot';
