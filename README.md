aiven-extras
============

This extension is meant for use in enviroments where you want non-superusers to be able
to use certain database features, such as creating logical replication connections using PostgreSQL 10+'s logical replications
SUBSCRIPTION/PUBLICATION concepts or configuring the `auto_explain` extension.

It allows you to use logical replication when installed originally by root and the
user using it has the REPLICATION privilege.

Installation
============

To create the Aiven extras extension, run the following after connecting to the database you wish to enable it in:

```sql
$ CREATE EXTENSION aiven_extras;
CREATE EXTENSION
```

Usage
=====

*The functions included are:*

|                   Name                    |               Result data type               |                                                                               Argument data types                                                                                |
|-------------------------------------------|----------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| auto_explain_load                         | void                                         |                                                                                                                                                                                  |
| claim_public_schema_ownership             | void                                         |                                                                                                                                                                                  |
| dblink_record_execute                     | SETOF record                                 | text, text                                                                                                                                                                       |
| dblink_slot_create_or_drop                | void                                         | arg_connection_string text, arg_slot_name text, arg_action text                                                                                                                  |
| pg_alter_subscription_disable             | void                                         | arg_subscription_name text                                                                                                                                                       |
| pg_alter_subscription_enable              | void                                         | arg_subscription_name text                                                                                                                                                       |
| pg_alter_subscription_refresh_publication | void                                         | arg_subscription_name text, arg_copy_data boolean DEFAULT true                                                                                                                   |
| pg_create_publication                     | void                                         | arg_publication_name text, arg_publish text, VARIADIC arg_tables text[] DEFAULT ARRAY[]::text[]                                                                                  |
| pg_create_publication_for_all_tables      | void                                         | arg_publication_name text, arg_publish text                                                                                                                                      |
| pg_create_subscription                    | void                                         | arg_subscription_name text, arg_connection_string text, arg_publication_name text, arg_slot_name text, arg_slot_create boolean DEFAULT false, arg_copy_data boolean DEFAULT true |
| pg_drop_subscription                      | void                                         | arg_subscription_name text                                                                                                                                                       |
| pg_list_all_subscriptions                 | SETOF aiven_extras.aiven_pg_subscription     |                                                                                                                                                                                  |
| pg_stat_replication_list                  | SETOF aiven_extras.aiven_pg_stat_replication |                                                                                                                                                                                  |
| session_replication_role                  | text                                         | arg_parameter text                                                                                                                                                               |
| set_auto_explain_log_analyze              | text                                         | arg_parameter text                                                                                                                                                               |
| set_auto_explain_log_buffers              | text                                         | arg_parameter text                                                                                                                                                               |
| set_auto_explain_log_format               | text                                         | arg_parameter text                                                                                                                                                               |
| set_auto_explain_log_min_duration         | text                                         | arg_parameter text                                                                                                                                                               |
| set_auto_explain_log_nested_statements    | text                                         | arg_parameter text                                                                                                                                                               |
| set_auto_explain_log_timing               | text                                         | arg_parameter text                                                                                                                                                               |
| set_auto_explain_log_verbose              | text                                         | arg_parameter text                                                                                                                                                               |

Examples
--------

**Managing subscriptions:**

```sql
aiven_extras.pg_create_subscription(
    arg_subscription_name TEXT,
    arg_connection_string TEXT,
    arg_publication_name TEXT,
    arg_slot_name TEXT = NULL
    arg_slot_create BOOL = FALSE,
    arg_copy_data BOOL = TRUE);

$ SELECT * FROM aiven_extras.pg_create_subscription(
      'subscription',
      'dbname=defaultdb host=destination-demoprj.aivencloud.com port=26882 sslmode=require user=avnadmin password=secret',
      'pub1',
      'slot',
      TRUE,
      TRUE
  );

$ SELECT * FROM aiven_extras.pg_list_all_subscriptions();

aiven_extras.pg_drop_subscription(arg_subscription_name TEXT)

$ SELECT * FROM aiven_extras.pg_drop_subscription('subscription');

aiven_extras.pg_create_publication_for_all_tables(
 arg_publication_name TEXT,
 arg_publish TEXT)

$ SELECT * FROM aiven_extras.pg_create_publication_for_all_tables('pub1', 'INSERT');

pg_alter_subscription_disable(arg_subscription_name TEXT)

$ SELECT * FROM aiven_extras.pg_alter_subscription_disable('subscription');

pg_alter_subscription_enable(arg_subscription_name TEXT)

$ SELECT * FROM aiven_extras.pg_alter_subscription_enable('subscription');

pg_alter_subscription_refresh_publication(
    arg_subscription_name TEXT,
    arg_copy_data BOOLEAN = TRUE
)

$ SELECT * FROM aiven_extras.pg_alter_subscription_refresh_publication('subscription', FALSE);
```

**Configuring auto-explain:**

For details, refer to [PostgreSQL's documentation](https://www.postgresql.org/docs/current/auto-explain.html), but note that arguments for the exposed functions are of type `text`. Also note that currently `aiven_extras` implements a subset of the available functions.

```sql
$ SELECT * FROM aiven_extras.auto_explain_load();
-- Set minimum duration to 2000 ms
$ SELECT * FROM aiven_extras.set_auto_explain_log_min_duration('2000');
-- Enable ANALYZE
$ SELECT * FROM aiven_extras.set_auto_explain_log_analyze('on');
```

License
=======

Aiven extras Extension is licensed under the Apache License, Version 2.0. Full license text
is available in the ``LICENSE`` file and at http://www.apache.org/licenses/LICENSE-2.0.txt


Credits
=======

Aiven extras extension was created by Hannu Valtonen <hannu.valtonen@aiven.io> for
`Aiven Cloud Database` and is now maintained by Aiven developers.

`Aiven Cloud Database`: https://aiven.io/

Recent contributors are listed on the GitHub project page,
https://github.com/aiven/aiven-extras/graphs/contributors


Contact
=======

Bug reports and patches are very welcome, please post them as GitHub issues
and pull requests at https://github.com/aiven/aiven-extras . Any possible
vulnerabilities or other serious issues should be reported directly to the
maintainers <opensource@aiven.io>.


Copyright
=========

Copyright (C) 2018 Aiven Ltd
