CREATE FUNCTION pg_alter_subscription_disable(
    arg_subscription_name TEXT
)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    EXECUTE format('ALTER SUBSCRIPTION %I DISABLE', arg_subscription_name);
END;
$$ SECURITY DEFINER;


CREATE FUNCTION pg_alter_subscription_enable(
    arg_subscription_name TEXT
)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    EXECUTE format('ALTER SUBSCRIPTION %I ENABLE', arg_subscription_name);
END;
$$ SECURITY DEFINER;


CREATE FUNCTION pg_alter_subscription_refresh_publication(
    arg_subscription_name TEXT,
    arg_copy_data BOOLEAN = TRUE
)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    EXECUTE format(
        'ALTER SUBSCRIPTION %I REFRESH PUBLICATION WITH (copy_data=%s)',
        arg_subscription_name, arg_copy_data::TEXT);
END;
$$ SECURITY DEFINER;

