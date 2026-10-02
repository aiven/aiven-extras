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
