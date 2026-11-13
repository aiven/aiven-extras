-- pg_alter_subscription_refresh_publication() is now the C function itself (no plpgsql wrapper,
-- no helper function). The SECURITY DEFINER attribute is only needed before PG 16, where only
-- superusers can own and alter subscriptions; on PG 16+ it runs as the caller and PostgreSQL's
-- own ownership check applies.
-- Drop the helper of the unreleased 71b11bb build, if present.
DROP FUNCTION IF EXISTS aiven_extras.subscription_refresh(TEXT, BOOLEAN);

CREATE OR REPLACE FUNCTION aiven_extras.pg_alter_subscription_refresh_publication(
    arg_subscription_name TEXT,
    arg_copy_data BOOLEAN = TRUE
)
RETURNS VOID
AS 'MODULE_PATHNAME', 'subscription_refresh'
LANGUAGE C
SET search_path = pg_catalog, pg_temp;

DO $$
BEGIN
  IF pg_catalog.current_setting('server_version_num')::int OPERATOR(pg_catalog.<) 160000 THEN
        ALTER FUNCTION aiven_extras.pg_alter_subscription_refresh_publication(TEXT, BOOLEAN) SECURITY DEFINER;
  ELSE
        ALTER FUNCTION aiven_extras.pg_alter_subscription_refresh_publication(TEXT, BOOLEAN) SECURITY INVOKER;
  END IF;
END;
$$ language plpgsql;
