# Odin command line tool

The tool can be used to administer the configuration of the Odin authentication and authorization system. The tool is accessed through the command `odin`.

    $ odin -?
    Manage an Odin database

        odin [opts] command [args]

    ...



### Assign permissions to a group

    assign group permission1 [permission2 [permission3 ...]]

Assign one or more permissions to a group.

### Remove user from groups

    exclude username group1 [group2 [group3 ...]]

Remove the user from the specified groups. Requires the `authz` module.

### Expire a user account

    expire username [time-date|never]

Expire the identity for the user at this time. If no expiry time is set then the account is expired immediatly. Alternatively a time/date can be passed, or the word `never` to unset the expiry.

Expiring an account doesn't revoke any JWT that has already been issued, but does stop new ones from being issued. All permissions are immediatly revoked so the account loses the ability to perform any permissioned action.

### Set a user's full name

    full-name username "Full Name"

Set the full name field. Requres module `opt/full-name`

### Create a group

    group name [description]

Set up a group and its description.

### Run script in another filename

    include filename

Find commands (one per line) in the specified file and run them

### Listing users

    list [users|user-groups|user-permissions]

List information about the current configuration of the system.

* users -- List all users and their names
* user-groups -- List the groups that users belong to with the group names
* user-permissions -- List all permissions that users have

Superusers are listed as members of all groups and as having all permissions whether or not they've been explicitly added to any groups.

Expired user accounts are shown as belonging to the correct groups, but do not list any permissions.

### Add a user to one or more groups

    membership user group1 [group2 [group3 ...]]

Add the user to one or more groups. Requires the `authz` module.

### Set password

    password name [password]

Set (or reset) the user's password. If the password is not provided as part of the command then the tool will prompt the user to enter one.  Setting the password requires the module `authn`.

### Create permissions

    permission name [description]

Set up a permission and its description.

### Run a SQL script

    sql filename

Load the filename and present the SQL in it to the database for execution. This is useful for choosing migrations scripts to run.

### Create a user

    user username [password]

Ensure the requested user is in the system. Setting the password requires the module `authn`. If the password is left out here then no password will be set. To create a user and prompt for a password use the `password` command:

    $ odin user example-user
    example-user set up
    $ odin password example-user
    Password:
    Password:
    example-user password set

### Grant or revoke super user privileges

    superuser username [True|False]

Sets the superuser bit (defaults to True). Requires the `authz` module.


## Restricting access to the tool's abilities

In order to use the tool to securetly administer users it must be:

* Run under a Unix user account that has no root privileges
* Make use of a Postgres role that has no grants over the database except for those detailed below

When restricted in this way the tool will still list its full capabilities, but any attempt to use a feature that it has no permission for will result in an error. For example:

    $ odin user example-user
    ** Postgres error
    permission denied for relation identity_ledger

The following base requirements are always needed:

* Ability to login to the database.
* Access to the `odin` schema.
* `SELECT` on the `odin.module` table.

Example SQL below assumes a Postgres role named `uadmin` is to be used for running the tool.

    # create role uadmin login;
    # grant usage on schema odin to uadmin;
    # grant SELECT on odin.module to uadmin;

These grants are dependant on the low level implementation of Odin and can change for any release in the future.

### Create users

Covers the `user` command.

    # grant INSERT on odin.identity_ledger to uadmin;

In order to set a password the following is also needed:

    # grant INSERT on odin.credentials_password_ledger to uadmin;

The full name (`full-name` command) requires:

    # grant INSERT on odin.identity_full_name_ledger to uadmin;

### Expire user account

    # grant INSERT on odin.identity_expiry_ledger to uadmin;
    # grant SELECT on odin.identity to uadmin;

The SELECT grant is only needed if the expiry is set to a particular time (so as to read the time the database recorded). If the `expire` command is only used without option, or with `never` then the SELECT is not needed.

### Displaying information about users

The `list` commmand provides several options for displaying information about users. These rely on the following SELECT permissions:

* users -- `grant SELECT on odin.identity to uadmin;`
* user-groups -- `grant SELECT on odin.identity, odin.group, odin.group_membership to uadmin;`
* user-permissions -- `grant SELECT on odin.identity, odin.group_grant, odin.group_membership to uadmin;`

### Add and remove groups

Covers the `membership` and `exclude` commands.

    # grant INSERT on odin.group_membership_ledger to uadmin;

