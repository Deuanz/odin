# Managing database schemas #

These schemas are intended to be run in numerical order with blue before green. Modules run in the order:

1. core
2. authn
3. authz
4. authz-pg
5. opt/*

So, run all `001.blue` scripts for the modules you need before you run any `001.green` ones. Then you can move on to `002` etc.

Before any of the modules can be loaded the `bootstrap.sql` must be run in the database you want to put the Odin data into.

Individual migration files can be easily run using the Python `odin` command.


## core ##

Central management of the identity of the users of a system.


## authn ##

Authentication. Primarily to do with ascertaining the identiy of a user. Manages the user's passwords.


## authz ##

Athorization. Primarily to do with ascertaining what a user is allowed to do in the system. Manages user's group membership and the assignment of permissions to groups.


## authz-pg ##

Handles management of user authorization through Postgres roles.


## opts ##

There are various optional modules under opts.

### full-name ###

Adds a full name field to the identity.

### logout ###

Adds a log out count which is used to verify JWT. This allows an account to log out and revoke all JWTs, but means that the Odin database must be accessed in order to verify that a JWT is valid. This module requires the `authn` module to be loaded.


# Schema rationale #

The schema is designed to provide tracking of changes for auditability. It is also designed to enforce as much as possible of the data storage rules.

In general application code is expected to write entries into the `ledger` tables whose triggers then make the requested change in the underlying data table.


# Notes on specific migrations #

Some migrations will have choices depending on how you want to manage certain features. For example, if you want to use the identity field for the log in name or the user's password.
