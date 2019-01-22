CREATE FUNCTION dblink_slot_create_or_drop(
    arg_connection_string TEXT,
    arg_slot_name TEXT,
    arg_action TEXT
)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    l_slot_existence_query TEXT := format('SELECT TRUE FROM pg_catalog.pg_replication_slots WHERE slot_name = %L', arg_slot_name);
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
    EXECUTE format(
        'SELECT res FROM %I.dblink(%L, %L) AS d(res BOOLEAN)',
        l_dblink_nsp, arg_connection_string, l_slot_existence_query)
        INTO l_slot_exists;
    IF arg_action = 'create' AND l_slot_exists IS NOT TRUE THEN
        l_slot_action_query := format('SELECT TRUE FROM pg_catalog.pg_create_logical_replication_slot(%L, %L, FALSE)', arg_slot_name, 'pgoutput');
    ELSIF arg_action = 'drop' AND l_slot_exists IS TRUE THEN
        l_slot_action_query := format('SELECT TRUE FROM pg_catalog.pg_drop_replication_slot(%L)', arg_slot_name);
    END IF;
    IF l_slot_action_query IS NOT NULL THEN
        EXECUTE format(
            'SELECT res FROM %I.dblink(%L, %L) AS d(res BOOLEAN)',
            l_dblink_nsp, arg_connection_string, l_slot_action_query);
    END IF;
END;
$$;


CREATE FUNCTION pg_create_subscription(
    arg_subscription_name TEXT,
    arg_connection_string TEXT,
    arg_publication_name TEXT,
    arg_slot_name TEXT,
    arg_slot_create BOOLEAN = FALSE,
    arg_copy_data BOOLEAN = TRUE
)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    l_slot_create_query TEXT;
BEGIN
    IF (arg_slot_create IS TRUE) THEN
        PERFORM aiven_extras.dblink_slot_create_or_drop(arg_connection_string, arg_slot_name, 'create');
    END IF;
    EXECUTE format(
        'CREATE SUBSCRIPTION %I connection %L publication %I WITH (slot_name=%L, create_slot=FALSE, copy_data=%s)',
        arg_subscription_name, arg_connection_string, arg_publication_name, arg_slot_name, arg_copy_data::TEXT);
END;
$$ SECURITY DEFINER;


CREATE FUNCTION pg_drop_subscription(
    arg_subscription_name TEXT
)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    l_slot_drop_query TEXT;
    l_slot_name TEXT;
    l_subconninfo TEXT;
BEGIN
    SELECT subslotname, subconninfo INTO l_slot_name, l_subconninfo FROM pg_subscription WHERE subname = arg_subscription_name;
    IF l_slot_name IS NULL AND l_subconninfo IS NULL THEN
        RAISE EXCEPTION 'No subscription found for name: %', arg_subscription_name;
    END IF;
    EXECUTE format('ALTER SUBSCRIPTION %I DISABLE', arg_subscription_name);
    EXECUTE format('ALTER SUBSCRIPTION %I SET (slot_name = NONE)', arg_subscription_name);
    EXECUTE format('DROP SUBSCRIPTION %I', arg_subscription_name);
    PERFORM aiven_extras.dblink_slot_create_or_drop(l_subconninfo, l_slot_name, 'drop');
END;
$$ SECURITY DEFINER;


CREATE FUNCTION pg_create_publication_for_all_tables(
    arg_publication_name TEXT,
    arg_publish TEXT
)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    EXECUTE format('CREATE PUBLICATION %I FOR ALL TABLES WITH (publish = %I)', arg_publication_name, arg_publish);
    EXECUTE format('ALTER PUBLICATION %I OWNER TO %I', arg_publication_name, session_user);
END;
$$ SECURITY DEFINER;


CREATE TYPE aiven_pg_subscription AS (
    subdbid OID,
    subname NAME,
    subowner OID,
    subenabled BOOLEAN,
    subconninfo TEXT,
    subslotname NAME,
    subsynccommit TEXT,
    subpublications TEXT[]
);

-- In PLPGSQL instead of SQL so we can create the function on pre-PG10
CREATE FUNCTION pg_list_all_subscriptions()
RETURNS SETOF aiven_pg_subscription LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY SELECT subdbid, subname, subowner, subenabled, subconninfo, subslotname, subsynccommit, subpublications FROM pg_catalog.pg_subscription;
END;
$$ SECURITY DEFINER;


--Adapted from comment by C. Keane at https://forums.aws.amazon.com/thread.jspa?messageID=561509#jive-message-527767

CREATE FUNCTION session_replication_role(
    role TEXT
)
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE
    curr_val text := 'unset';
BEGIN
    EXECUTE 'SET session_replication_role = ' || quote_literal(role);
    EXECUTE 'SHOW session_replication_role' INTO curr_val;
    RETURN curr_val;
END
$$ SECURITY DEFINER;


CREATE FUNCTION auto_explain_load()
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    EXECUTE FORMAT('LOAD %L', 'auto_explain');
END;
$$ SECURITY DEFINER;


CREATE FUNCTION set_auto_explain_log_analyze(
    parameter TEXT
)
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE
    curr_val text := 'unset';
BEGIN
    EXECUTE 'SET auto_explain.log_analyze = ' || quote_literal(parameter);
    EXECUTE 'SHOW auto_explain.log_analyze' INTO curr_val;
    RETURN curr_val;
END
$$ SECURITY DEFINER;


CREATE FUNCTION set_auto_explain_log_format(
    parameter TEXT
)
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE
    curr_val text := 'unset';
BEGIN
    EXECUTE 'SET auto_explain.log_format = ' || quote_literal(parameter);
    EXECUTE 'SHOW auto_explain.log_format' INTO curr_val;
    RETURN curr_val;
END
$$ SECURITY DEFINER;


CREATE FUNCTION set_auto_explain_log_min_duration(
    parameter TEXT
)
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE
    curr_val text := 'unset';
BEGIN
    EXECUTE 'SET auto_explain.log_min_duration = ' || quote_literal(parameter);
    EXECUTE 'SHOW auto_explain.log_min_duration' INTO curr_val;
    RETURN curr_val;
END
$$ SECURITY DEFINER;


CREATE FUNCTION set_auto_explain_log_timing(
    parameter TEXT
)
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE
    curr_val text := 'unset';
BEGIN
    EXECUTE 'SET auto_explain.log_timing = ' || quote_literal(parameter);
    EXECUTE 'SHOW auto_explain.log_timing' INTO curr_val;
    RETURN curr_val;
END
$$ SECURITY DEFINER;


CREATE FUNCTION set_auto_explain_log_buffers(
    parameter TEXT
)
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE
    curr_val text := 'unset';
BEGIN
    EXECUTE 'SET auto_explain.log_buffers = ' || quote_literal(parameter);
    EXECUTE 'SHOW auto_explain.log_buffers' INTO curr_val;
    RETURN curr_val;
END
$$ SECURITY DEFINER;


CREATE FUNCTION set_auto_explain_log_verbose(
    parameter TEXT
)
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE
    curr_val text := 'unset';
BEGIN
    EXECUTE 'SET auto_explain.log_verbose = ' || quote_literal(parameter);
    EXECUTE 'SHOW auto_explain.log_verbose' INTO curr_val;
    RETURN curr_val;
END
$$ SECURITY DEFINER;


CREATE FUNCTION set_auto_explain_log_nested_statements(
    parameter TEXT
)
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE
    curr_val text := 'unset';
BEGIN
    EXECUTE 'SET auto_explain.log_nested_statements = ' || quote_literal(parameter);
    EXECUTE 'SHOW auto_explain.log_nested_statements' INTO curr_val;
    RETURN curr_val;
END
$$ SECURITY DEFINER;


CREATE FUNCTION claim_public_schema_ownership()
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    EXECUTE format('ALTER SCHEMA public OWNER TO %I', session_user);
END;
$$ SECURITY DEFINER;


CREATE TYPE aiven_pg_stat_replication AS (
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


CREATE FUNCTION pg_stat_replication_list()
RETURNS SETOF aiven_pg_stat_replication LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY EXECUTE format('SELECT pid, usesysid, usename, application_name, client_addr, client_hostname, client_port,
                                     backend_start, backend_xmin, state, sent_lsn, write_lsn, flush_lsn, replay_lsn, write_lag,
                                     flush_lag, replay_lag, sync_priority, sync_state
                                     FROM pg_catalog.pg_stat_replication
                                     WHERE usename = %L::NAME', session_user);
END;
$$ SECURITY DEFINER;


CREATE VIEW pg_stat_replication AS
    SELECT pid, usesysid, usename, application_name, client_addr, client_hostname, client_port,
        backend_start, backend_xmin, state, sent_lsn, write_lsn, flush_lsn, replay_lsn, write_lag,
        flush_lag, replay_lag, sync_priority, sync_state
	FROM pg_stat_replication_list();
