DROP FUNCTION IF EXISTS pg_list_all_subscriptions;

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

CREATE FUNCTION pg_list_all_subscriptions()
RETURNS SETOF aiven_pg_subscription LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY SELECT subdbid, subname, subowner, subenabled, subconninfo, subslotname, subsynccommit, subpublications FROM pg_catalog.pg_subscription;
END;
$$ SECURITY DEFINER;

--Adapted from comment by C. Keane at https://forums.aws.amazon.com/thread.jspa?messageID=561509#jive-message-527767

CREATE OR REPLACE FUNCTION session_replication_role(
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
