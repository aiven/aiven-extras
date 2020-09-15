aiven-extras
============

This extension is meant for use in enviroments where you want non-superusers to be able
to create logical replication connections using PostgreSQL 10+'s logical replications
SUBSCRIPTION/PUBLICATION concepts.

It allows you to use logical replication when installed originally by root and the
user using it has the REPLICATION privilege.

Installation
============

To create the Aiven extras extension run:

    $ CREATE EXTENSION aiven_extras;
    CREATE EXTENSION

Usage
=====

The functions included are:

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
