DROP FUNCTION IF EXISTS aiven_extras.subscription_refresh(TEXT, BOOLEAN);
CREATE FUNCTION aiven_extras.subscription_refresh(
	arg_subscription_name TEXT,
	arg_copy_data BOOLEAN)
RETURNS VOID
AS 'MODULE_PATHNAME', 'subscription_refresh'
LANGUAGE C STRICT;
REVOKE EXECUTE ON FUNCTION aiven_extras.subscription_refresh(TEXT, BOOLEAN) FROM PUBLIC;

CREATE OR REPLACE FUNCTION aiven_extras.pg_alter_subscription_refresh_publication(
    arg_subscription_name TEXT,
    arg_copy_data BOOLEAN = TRUE
)
RETURNS VOID LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    -- aiven_extras.subscription_refresh() is STRICT, so reject NULL arguments
    -- explicitly instead of silently doing nothing.
    IF arg_subscription_name IS NULL THEN
        RAISE EXCEPTION 'arg_subscription_name must not be NULL';
    END IF;
    IF arg_copy_data IS NULL THEN
        RAISE EXCEPTION 'arg_copy_data must not be NULL';
    END IF;
    PERFORM aiven_extras.subscription_refresh(arg_subscription_name, arg_copy_data);
END;
$$;
REVOKE EXECUTE ON FUNCTION aiven_extras.pg_alter_subscription_refresh_publication(TEXT, BOOLEAN) FROM PUBLIC;

-- pg-prune repair rewinds extversion and re-runs this script as the extension owner. Re-apply
-- trusted-extension-style EXECUTE (and view SELECT) grants for existing objects. Use extowner from
-- pg_extension, not @extowner@: upgrade scripts only expand that token on PostgreSQL 13+.
DO $$
DECLARE
    l_owner name;
    l_func record;
BEGIN
    SELECT r.rolname
    INTO l_owner
    FROM pg_catalog.pg_extension AS e
    JOIN pg_catalog.pg_roles AS r ON r.oid = e.extowner
    WHERE e.extname = 'aiven_extras';
    FOR l_func IN
        SELECT p.proname, pg_catalog.pg_get_function_identity_arguments(p.oid) AS args
        FROM pg_catalog.pg_proc AS p
        JOIN pg_catalog.pg_namespace AS n ON n.oid = p.pronamespace
        WHERE n.nspname = 'aiven_extras'
          AND p.prokind = 'f'
          AND p.proname <> 'subscription_refresh'
    LOOP
        EXECUTE pg_catalog.format(
            'GRANT EXECUTE ON FUNCTION aiven_extras.%I(%s) TO %I WITH GRANT OPTION',
            l_func.proname,
            l_func.args,
            l_owner
        );
    END LOOP;
    EXECUTE pg_catalog.format(
        'GRANT SELECT ON aiven_extras.pg_stat_replication TO %I WITH GRANT OPTION',
        l_owner
    );
END;
$$;
