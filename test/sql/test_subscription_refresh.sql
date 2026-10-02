CREATE EXTENSION IF NOT EXISTS aiven_extras;

-- The internal C helper and the wrapper must not be callable by PUBLIC.
SELECT has_function_privilege('public', 'aiven_extras.subscription_refresh(text, boolean)', 'EXECUTE') AS helper_public_execute;
SELECT has_function_privilege('public', 'aiven_extras.pg_alter_subscription_refresh_publication(text, boolean)', 'EXECUTE') AS wrapper_public_execute;

-- NULL arguments must be rejected rather than silently doing nothing.
SELECT aiven_extras.pg_alter_subscription_refresh_publication(NULL, FALSE);
SELECT aiven_extras.pg_alter_subscription_refresh_publication('test_sub', NULL);

-- An unknown subscription is reported by PostgreSQL itself.
SELECT aiven_extras.pg_alter_subscription_refresh_publication('no_such_subscription', FALSE);

SET client_min_messages = error;
CREATE SUBSCRIPTION test_sub
    CONNECTION 'dbname=aiven_extras_no_such_db'
    PUBLICATION test_pub
    WITH (connect = false, slot_name = NONE);
CREATE SUBSCRIPTION "Test Sub ""quoted"""
    CONNECTION 'dbname=aiven_extras_no_such_db'
    PUBLICATION test_pub
    WITH (connect = false, slot_name = NONE);
RESET client_min_messages;

-- Reaching the REFRESH code path proves the statement is dispatched from
-- inside the SECURITY DEFINER wrapper instead of being rejected with
-- "cannot be executed from a function", and without a dblink loopback.
SELECT aiven_extras.pg_alter_subscription_refresh_publication('test_sub', FALSE);

-- Identifiers are quoted, so names needing quoting reach PostgreSQL intact.
SELECT aiven_extras.pg_alter_subscription_refresh_publication('Test Sub "quoted"', TRUE);

DROP SUBSCRIPTION test_sub;
DROP SUBSCRIPTION "Test Sub ""quoted""";
