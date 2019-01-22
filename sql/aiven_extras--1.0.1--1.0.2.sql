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
