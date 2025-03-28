DROP FUNCTION IF EXISTS aiven_extras.set_pgaudit_parameter(TEXT, TEXT, TEXT);
CREATE FUNCTION aiven_extras.set_pgaudit_parameter(
    arg_parameter TEXT,
    arg_database TEXT,
    arg_value TEXT
)
RETURNS VOID LANGUAGE plpgsql
SET search_path = pg_catalog, aiven_extras
AS $$
BEGIN
	IF current_setting('server_version_num')::int >= 150000 THEN
		RAISE WARNING 'This function is deprecated, changing superuser-reserved GUC is now grantable to roles';
	END IF;
    IF COALESCE(
        (SELECT usesuper
            FROM pg_catalog.pg_database d
                JOIN pg_catalog.pg_user u
                    ON (u.usesysid = d.datdba)
                WHERE d.datname = arg_database
                LIMIT 1
        ),
        TRUE
    ) THEN
        RAISE EXCEPTION 'Invalid database: %', arg_database;
    ELSIF arg_parameter NOT IN (
        'log',
        'log_catalog',
        'log_max_string_length',
        'log_nested_statements',
        'log_parameter',
        'log_relation',
        'log_statement',
        'log_statement_once'
    ) THEN
        RAISE EXCEPTION 'Invalid parameter: %', arg_parameter;
    END IF;

    EXECUTE pg_catalog.format('ALTER DATABASE %I SET pgaudit.%I = %L',
        arg_database,
        arg_parameter,
        arg_value
    );
END;
$$;



DROP FUNCTION IF EXISTS aiven_extras.set_pgaudit_role_parameter(TEXT, TEXT, TEXT);
CREATE FUNCTION aiven_extras.set_pgaudit_role_parameter(
    arg_parameter TEXT,
    arg_role TEXT,
    arg_value TEXT
)
RETURNS VOID LANGUAGE plpgsql
SET search_path = pg_catalog, aiven_extras
AS $$
BEGIN
	IF current_setting('server_version_num')::int >= 150000 THEN
		RAISE WARNING 'This function is deprecated, changing superuser-reserved GUC is now grantable to roles';
	END IF;
    IF COALESCE(
        (SELECT rolsuper
            FROM pg_catalog.pg_roles
                WHERE rolname = arg_role
                LIMIT 1
        ),
        FALSE
    ) THEN
        RAISE EXCEPTION 'Configuring superuser roles not allowed: %', arg_role;
    ELSIF arg_parameter NOT IN (
        'log',
        'log_catalog',
        'log_max_string_length',
        'log_nested_statements',
        'log_parameter',
        'log_relation',
        'log_statement',
        'log_statement_once'
    ) THEN
        RAISE EXCEPTION 'Invalid parameter: %', arg_parameter;
    END IF;

    EXECUTE format('ALTER ROLE %I SET pgaudit.%I = %L',
        arg_role,
        arg_parameter,
        arg_value
    );
END;
$$;

DO $$
BEGIN
  IF current_setting('server_version_num')::int < 150000 THEN
        ALTER FUNCTION aiven_extras.set_pgaudit_parameter(text, text, text) SECURITY DEFINER;
        ALTER FUNCTION aiven_extras.set_pgaudit_role_parameter(text, text, text) SECURITY DEFINER;
  ELSE
        ALTER FUNCTION aiven_extras.set_pgaudit_parameter(text, text, text) SECURITY INVOKER;
        ALTER FUNCTION aiven_extras.set_pgaudit_role_parameter(text, text, text) SECURITY INVOKER;
  END IF;
END;
$$ language plpgsql;
