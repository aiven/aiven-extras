DO $$
BEGIN
    PERFORM 1 FROM pg_catalog.pg_type WHERE typnamespace = 'aiven_extras'::regnamespace AND typname = 'aiven_pg_subscription';
    IF NOT FOUND THEN
        CREATE TYPE aiven_extras.aiven_pg_subscription AS (
            subdbid OID,
            subname NAME,
            subowner OID,
            subenabled BOOLEAN,
            subconninfo TEXT,
            subslotname NAME,
            subsynccommit TEXT,
            subpublications TEXT[]
        );
    END IF;
    PERFORM 1 FROM pg_catalog.pg_type WHERE typnamespace = 'aiven_extras'::regnamespace AND typname = 'aiven_pg_stat_replication';
    IF NOT FOUND THEN
        CREATE TYPE aiven_extras.aiven_pg_stat_replication AS (
            pid INT,
            usesysid OID,
            usename NAME,
            application_name TEXT,
            client_addr INET,
            client_hostname TEXT,
            client_port INT,
            backend_start TIMESTAMP WITH TIME ZONE,
            backend_xmin XID,
            state TEXT,
            sent_lsn PG_LSN,
            write_lsn PG_LSN,
            flush_lsn PG_LSN,
            replay_lsn PG_LSN,
            write_lag INTERVAL,
            flush_lag INTERVAL,
            replay_lag INTERVAL,
            sync_priority INTEGER,
            sync_state TEXT
        );
    END IF;
END;
$$;


DROP FUNCTION IF EXISTS aiven_extras.dblink_slot_create_or_drop(TEXT, TEXT, TEXT);
CREATE FUNCTION aiven_extras.dblink_slot_create_or_drop(
    arg_connection_string TEXT,
    arg_slot_name TEXT,
    arg_action TEXT
)
RETURNS VOID LANGUAGE plpgsql
SET search_path = aiven_extras, pg_catalog, pg_temp
AS $$
DECLARE
    l_slot_existence_query TEXT := pg_catalog.format('SELECT TRUE FROM pg_catalog.pg_replication_slots WHERE slot_name = %L', arg_slot_name);
    l_slot_action_query TEXT;
    l_dblink_nsp TEXT;
    l_slot_exists BOOLEAN;
BEGIN
    SELECT nspname
        INTO l_dblink_nsp
        FROM pg_catalog.pg_extension AS pge
            JOIN pg_catalog.pg_namespace AS pgns
                ON (pge.extnamespace = pgns.oid)
        WHERE pge.extname = 'dblink';
    EXECUTE pg_catalog.format(
        'SELECT res FROM %I.dblink(%L, %L) AS d(res BOOLEAN)',
        l_dblink_nsp, arg_connection_string, l_slot_existence_query)
        INTO l_slot_exists;
    IF arg_action = 'create' AND l_slot_exists IS NOT TRUE THEN
        l_slot_action_query := pg_catalog.format('SELECT TRUE FROM pg_catalog.pg_create_logical_replication_slot(%L, %L, FALSE)', arg_slot_name, 'pgoutput');
    ELSIF arg_action = 'drop' AND l_slot_exists IS TRUE THEN
        l_slot_action_query := pg_catalog.format('SELECT TRUE FROM pg_catalog.pg_drop_replication_slot(%L)', arg_slot_name);
    END IF;
    IF l_slot_action_query IS NOT NULL THEN
        EXECUTE pg_catalog.format(
            'SELECT res FROM %I.dblink(%L, %L) AS d(res BOOLEAN)',
            l_dblink_nsp, arg_connection_string, l_slot_action_query);
    END IF;
END;
$$;


DROP FUNCTION IF EXISTS aiven_extras.pg_create_subscription(TEXT, TEXT, TEXT, TEXT, BOOLEAN, BOOLEAN);
CREATE FUNCTION aiven_extras.pg_create_subscription(
    arg_subscription_name TEXT,
    arg_connection_string TEXT,
    arg_publication_name TEXT,
    arg_slot_name TEXT,
    arg_slot_create BOOLEAN = FALSE,
    arg_copy_data BOOLEAN = TRUE
)
RETURNS VOID LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = aiven_extras, pg_catalog, pg_temp
AS $$
BEGIN
    IF (arg_slot_create IS TRUE) THEN
        PERFORM aiven_extras.dblink_slot_create_or_drop(arg_connection_string, arg_slot_name, 'create');
    END IF;
    EXECUTE pg_catalog.format(
        'CREATE SUBSCRIPTION %I connection %L publication %I WITH (slot_name=%L, create_slot=FALSE, copy_data=%s)',
        arg_subscription_name, arg_connection_string, arg_publication_name, arg_slot_name, arg_copy_data::TEXT);
END;
$$;


DROP FUNCTION IF EXISTS aiven_extras.pg_alter_subscription_disable(TEXT);
CREATE FUNCTION aiven_extras.pg_alter_subscription_disable(
    arg_subscription_name TEXT
)
RETURNS VOID LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = aiven_extras, pg_catalog, pg_temp
AS $$
BEGIN
    EXECUTE pg_catalog.format('ALTER SUBSCRIPTION %I DISABLE', arg_subscription_name);
END;
$$;


DROP FUNCTION IF EXISTS aiven_extras.pg_alter_subscription_enable(TEXT);
CREATE FUNCTION aiven_extras.pg_alter_subscription_enable(
    arg_subscription_name TEXT
)
RETURNS VOID LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = aiven_extras, pg_catalog, pg_temp
AS $$
BEGIN
    EXECUTE pg_catalog.format('ALTER SUBSCRIPTION %I ENABLE', arg_subscription_name);
END;
$$;


DROP FUNCTION IF EXISTS aiven_extras.pg_alter_subscription_refresh_publication(TEXT, BOOLEAN);
CREATE FUNCTION aiven_extras.pg_alter_subscription_refresh_publication(
    arg_subscription_name TEXT,
    arg_copy_data BOOLEAN = TRUE
)
RETURNS VOID LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = aiven_extras, pg_catalog, pg_temp
AS $$
BEGIN
    EXECUTE pg_catalog.format(
        'ALTER SUBSCRIPTION %I REFRESH PUBLICATION WITH (copy_data=%s)',
        arg_subscription_name, arg_copy_data::TEXT);
END;
$$;

DROP FUNCTION IF EXISTS aiven_extras.pg_drop_subscription(TEXT);
CREATE FUNCTION aiven_extras.pg_drop_subscription(
    arg_subscription_name TEXT
)
RETURNS VOID LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = aiven_extras, pg_catalog, pg_temp
AS $$
DECLARE
    l_slot_name TEXT;
    l_subconninfo TEXT;
BEGIN
    SELECT subslotname, subconninfo
        INTO l_slot_name, l_subconninfo
        FROM pg_catalog.pg_subscription
        WHERE subname = arg_subscription_name;
    IF l_slot_name IS NULL AND l_subconninfo IS NULL THEN
        RAISE EXCEPTION 'No subscription found for name: %', arg_subscription_name;
    END IF;
    EXECUTE pg_catalog.format('ALTER SUBSCRIPTION %I DISABLE', arg_subscription_name);
    EXECUTE pg_catalog.format('ALTER SUBSCRIPTION %I SET (slot_name = NONE)', arg_subscription_name);
    EXECUTE pg_catalog.format('DROP SUBSCRIPTION %I', arg_subscription_name);
    PERFORM aiven_extras.dblink_slot_create_or_drop(l_subconninfo, l_slot_name, 'drop');
END;
$$;


DROP FUNCTION IF EXISTS aiven_extras.pg_create_publication_for_all_tables(TEXT, TEXT);
CREATE FUNCTION aiven_extras.pg_create_publication_for_all_tables(
    arg_publication_name TEXT,
    arg_publish TEXT
)
RETURNS VOID LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = aiven_extras, pg_catalog, pg_temp
AS $$
BEGIN
    EXECUTE pg_catalog.format('CREATE PUBLICATION %I FOR ALL TABLES WITH (publish = %I)', arg_publication_name, arg_publish);
    EXECUTE pg_catalog.format('ALTER PUBLICATION %I OWNER TO %I', arg_publication_name, session_user);
END;
$$;

DROP FUNCTION IF EXISTS aiven_extras.pg_list_all_subscriptions();
CREATE FUNCTION aiven_extras.pg_list_all_subscriptions()
RETURNS SETOF aiven_extras.aiven_pg_subscription LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = aiven_extras, pg_catalog, pg_temp
AS $$
BEGIN
    RETURN QUERY
        SELECT subdbid, subname, subowner, subenabled, subconninfo, subslotname, subsynccommit, subpublications
            FROM pg_catalog.pg_subscription;
END;
$$;


DROP FUNCTION IF EXISTS aiven_extras.session_replication_role(TEXT);
CREATE FUNCTION aiven_extras.session_replication_role(
    arg_parameter TEXT
)
RETURNS TEXT LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = aiven_extras, pg_catalog, pg_temp
AS $$
BEGIN
    RETURN pg_catalog.set_config('session_replication_role', arg_role, false);
END
$$;


DROP FUNCTION IF EXISTS aiven_extras.auto_explain_load();
CREATE FUNCTION aiven_extras.auto_explain_load()
RETURNS VOID LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = aiven_extras, pg_catalog, pg_temp
AS $$
BEGIN
    LOAD 'auto_explain';
END;
$$;


DROP FUNCTION IF EXISTS aiven_extras.set_auto_explain_log_analyze(TEXT);
CREATE FUNCTION aiven_extras.set_auto_explain_log_analyze(
    arg_parameter TEXT
)
RETURNS TEXT LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = aiven_extras, pg_catalog, pg_temp
AS $$
BEGIN
    RETURN pg_catalog.set_config('auto_explain.log_analyze', arg_parameter, false);
END
$$;


DROP FUNCTION IF EXISTS aiven_extras.set_auto_explain_log_format(TEXT);
CREATE FUNCTION aiven_extras.set_auto_explain_log_format(
    arg_parameter TEXT
)
RETURNS TEXT LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = aiven_extras, pg_catalog, pg_temp
AS $$
BEGIN
    RETURN pg_catalog.set_config('auto_explain.log_format', arg_parameter, false);
END
$$;


DROP FUNCTION IF EXISTS aiven_extras.set_auto_explain_log_min_duration(TEXT);
CREATE FUNCTION aiven_extras.set_auto_explain_log_min_duration(
    arg_parameter TEXT
)
RETURNS TEXT LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = aiven_extras, pg_catalog, pg_temp
AS $$
BEGIN
    RETURN pg_catalog.set_config('auto_explain.log_min_duration', arg_parameter, false);
END
$$;


DROP FUNCTION IF EXISTS aiven_extras.set_auto_explain_log_timing(TEXT);
CREATE FUNCTION aiven_extras.set_auto_explain_log_timing(
    arg_parameter TEXT
)
RETURNS TEXT LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = aiven_extras, pg_catalog, pg_temp
AS $$
BEGIN
    RETURN pg_catalog.set_config('auto_explain.log_timing', arg_parameter, false);
END
$$;


DROP FUNCTION IF EXISTS aiven_extras.set_auto_explain_log_buffers(TEXT);
CREATE FUNCTION aiven_extras.set_auto_explain_log_buffers(
    arg_parameter TEXT
)
RETURNS TEXT LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = aiven_extras, pg_catalog, pg_temp
AS $$
BEGIN
    RETURN pg_catalog.set_config('auto_explain.log_buffers', arg_parameter, false);
END
$$;


DROP FUNCTION IF EXISTS aiven_extras.set_auto_explain_log_verbose(TEXT);
CREATE FUNCTION aiven_extras.set_auto_explain_log_verbose(
    arg_parameter TEXT
)
RETURNS TEXT LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = aiven_extras, pg_catalog, pg_temp
AS $$
BEGIN
    RETURN pg_catalog.set_config('auto_explain.log_verbose', arg_parameter, false);
END
$$;


DROP FUNCTION IF EXISTS aiven_extras.set_auto_explain_log_nested_statements(TEXT);
CREATE FUNCTION aiven_extras.set_auto_explain_log_nested_statements(
    arg_parameter TEXT
)
RETURNS TEXT LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = aiven_extras, pg_catalog, pg_temp
AS $$
BEGIN
    RETURN pg_catalog.set_config('auto_explain.log_nested_statements', arg_parameter, false);
END
$$;


DROP FUNCTION IF EXISTS aiven_extras.claim_public_schema_ownership();
CREATE FUNCTION aiven_extras.claim_public_schema_ownership()
RETURNS VOID LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = aiven_extras, pg_catalog, pg_temp
AS $$
BEGIN
    EXECUTE pg_catalog.format('ALTER SCHEMA public OWNER TO %I', session_user);
END;
$$;


-- Temporarily clear out the view so we can replace the function behind it
CREATE OR REPLACE VIEW aiven_extras.pg_stat_replication AS
    SELECT
        NULL::INT AS pid,
        NULL::OID AS usesysid,
        NULL::NAME AS usename,
        NULL::TEXT AS application_name,
        NULL::INET AS client_addr,
        NULL::TEXT AS client_hostname,
        NULL::INT AS client_port,
        NULL::TIMESTAMPTZ AS backend_start,
        NULL::XID AS backend_xmin,
        NULL::TEXT AS state,
        NULL::PG_LSN AS sent_lsn,
        NULL::PG_LSN AS write_lsn,
        NULL::PG_LSN AS flush_lsn,
        NULL::PG_LSN AS replay_lsn,
        NULL::INTERVAL AS write_lag,
        NULL::INTERVAL AS flush_lag,
        NULL::INTERVAL AS replay_lag,
        NULL::INTEGER AS sync_priority,
        NULL::TEXT AS sync_state;


DROP FUNCTION IF EXISTS aiven_extras.pg_stat_replication_list();
CREATE FUNCTION aiven_extras.pg_stat_replication_list()
RETURNS SETOF aiven_extras.aiven_pg_stat_replication LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = aiven_extras, pg_catalog, pg_temp
AS $$
BEGIN
    RETURN QUERY
        SELECT  pid, usesysid, usename, application_name, client_addr, client_hostname, client_port,
                backend_start, backend_xmin, state, sent_lsn, write_lsn, flush_lsn, replay_lsn, write_lag,
                flush_lag, replay_lag, sync_priority, sync_state
            FROM pg_catalog.pg_stat_replication
            WHERE usename = session_user;
END;
$$;


CREATE OR REPLACE VIEW aiven_extras.pg_stat_replication AS
        SELECT  pid, usesysid, usename, application_name, client_addr, client_hostname, client_port,
                backend_start, backend_xmin, state, sent_lsn, write_lsn, flush_lsn, replay_lsn, write_lag,
                flush_lag, replay_lag, sync_priority, sync_state
            FROM aiven_extras.pg_stat_replication_list();
