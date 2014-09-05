# NAME

DBIx::Class::Schema::Config - Credential Management for DBIx::Class

# DESCRIPTION

DBIx::Class::Schema::Config is a subclass of DBIx::Class::Schema that allows
the loading of credentials & configuration from a file.  The actual code itself
would only need to know about the name used in the configuration file. This
aims to make it simpler for operations teams to manage database credentials.

A simple tutorial that compliments this documentation and explains converting 
an existing DBIx::Class Schema to use this software to manage credentials can 
be found at [http://www.symkat.com/credential-management-in-dbix-class](http://www.symkat.com/credential-management-in-dbix-class)

# SYNOPSIS

    /etc/dbic.yaml
    MY_DATABASE:
        dsn: "dbi:Pg:host=localhost;database=blog"
        user: "TheDoctor"
        password: "dnoPydoleM"
        TraceLevel: 1

    package My::Schema
    use warnings;
    use strict;

    use base 'DBIx::Class::Schema::Config';
    __PACKAGE__->load_namespaces;

    package My::Code;
    use warnings;
    use strict;
    use My::Schema;

    my $schema = My::Schema->connect('MY_DATABASE');

    # arbitrary config access from anywhere in your $app
    my $level = My::Schema->config->{TraceLevel};

# CONFIG FILES

This module will load the files in the following order if they exist:

- `$ENV{DBIX_CONFIG_DIR}` . '/dbic',

    `$ENV{DBIX_CONFIG_DIR}` can be configured at run-time, for instance:

        DBIX_CONFIG_DIR="/var/local/" ./my_program.pl

- ./dbic.\*
- ~/.dbic.\*
- /etc/dbic.\*

The files should have an extension that [Config::Any](https://metacpan.org/pod/Config::Any) recognizes,
for example /etc/dbic.**yaml**.

NOTE:  The first available credential will be used.  Therefore _DATABASE_
in ~/.dbic.yaml will only be looked at if it was not found in ./dbic.yaml.
If there are duplicates in one file (such that DATABASE is listed twice in
~/.dbic.yaml,) the first configuration will be used.

# CHANGE CONFIG PATH

Use `__PACKAGE__->config_paths([( '/file/stub', '/var/www/etc/dbic')]);`
to change the paths that are searched.  For example:

    package My::Schema
    use warnings;
    use strict;

    use base 'DBIx::Class::Schema::Config';
    __PACKAGE__->config_paths([( '/var/www/secret/dbic', '/opt/database' )]);

The above code would have _/var/www/secret/dbic.\*_ and _/opt/database.\*_ 
searched, in that order.  As above, the first credentials found would be used.  
This will replace the files originally searched for, not add to them.

# USE SPECIFIC CONFIG FILES

If you would rather explicitly state the configuration files you
want loaded, you can use the class accessor `config_files`
instead.

    package My::Schema
    use warnings;
    use strict;

    use base 'DBIx::Class::Schema::Config';
    __PACKAGE__->config_files([( '/var/www/secret/dbic.yaml', '/opt/database.yaml' )]);

This will check the files, `/var/www/secret/dbic.yaml`,
and `/opt/database.yaml` in the same way as `config_paths`,
however it will only check the specific files, instead of checking
for each extension that [Config::Any](https://metacpan.org/pod/Config::Any) supports.  You MUST use the
extension that corresponds to the file type you are loading.
See [Config::Any](https://metacpan.org/pod/Config::Any) for information on supported file types and
extension mapping.

# ACCESSING THE CONFIG FILE

The config file is stored via the  `__PACKAGE__->config` accessor, which can be
called as both a class and instance method:

    package My::Schema
    use warnings;
    use strict;

    use base 'DBIx::Class::Schema::Config';
    __PACKAGE__->config_paths([( '/var/www/secret/dbic', '/opt/database' )]);

The above code would have _/var/www/secret/dbic.\*_ and _/opt/database.\*_
searched, in that order.  As above, the first credentials found would be used.
This will replace the files origionally searched for, not add to them.

# OVERRIDING

The API has been designed to be simple to override if you have additional
needs in loading DBIC configurations.

## Overriding Connection Configuration

Simple cases where one wants to replace specific configuration tokens can be
given as extra parameters in the ->connect call.

For example, suppose we have the database MY\_DATABASE from above:

    MY_DATABASE:
        dsn: "dbi:Pg:host=localhost;database=blog"
        user: "TheDoctor"
        password: "dnoPydoleM"
        TraceLevel: 1

If you’d like to replace the username with “Eccleston” and we’d like to turn 
PrintError off.

The following connect line would achieve this:

    $Schema->connect(“MY_DATABASE”, “Eccleston”, undef, { PrintError => 0 } );

The name of the connection to load from the configuration file is still given 
as the first argument, while the username and password follow and finally any 
extra attributes you’d like to override.

Please note that the username and password field must be set to undef if you 
are not overriding them and wish to use extra attributes to override or add 
additional configuration for the connection.

## filter\_loaded\_credentials

Override this function if you want to change the loaded credentials before
they are passed to DBIC.  This is useful for use-cases that include decrypting
encrypted passwords or making programmatic changes to the configuration before
using it.

    sub filter_loaded_credentials {
        my ( $class, $loaded_credentials, $connect_args ) = @_;
        ...
        return $loaded_credentials;
    }

`$loaded_credentials` is the structure after it has been loaded from the
configuration file.  In this case, `$loaded_credentials->{user}` eq
**WalterWhite** and `$loaded_credentials->{dsn}` eq
**DBI:mysql:database=students;host=%s;port=3306**.

`$connect_args` is the structure originally passed on `->connect()`
after it has been turned into a hash.  For instance,
`->connect('DATABASE', 'USERNAME')` will result in
`$connect_args->{dsn}` eq **DATABASE** and `$connect_args->{user}`
eq **USERNAME**.

Additional parameters can be added by appending a hashref,
to the connection call, as an example, `->connect( 'CONFIG',
{ hostname => "db.foo.com" } );` will give `$connect_args` a
structure like `{ dsn => 'CONFIG', hostname => "db.foo.com" }`.

For instance, if you want to use hostnames when you make the
initial connection to DBIC and are using the configuration primarily
for usernames, passwords and other configuration data, you can create
a config like the following:

    DATABASE:
        dsn: "DBI:mysql:database=students;host=%s;port=3306"
        user: "WalterWhite"
        password: "relykS"

In your Schema class, you could include the following:

    package My::Schema
    use warnings;
    use strict;
    use base 'DBIx::Class::Schema::Config';

    sub filter_loaded_credentials {
        my ( $class, $loaded_credentials, $connect_args ) = @_;
        if ( $loaded_credentials->{dsn} =~ /\%s/ ) {
            $loaded_credentials->{dsn} = sprintf( $loaded_credentials->{dsn},
                $connect_args->{hostname});
        }
    }

    __PACKAGE__->load_classes;
    1;

Then the connection could be done with
`$Schema->connect('DATABASE', { hostname =` 'my.hostname.com' });>

See ["load\_credentials"](#load_credentials) for more complex changes that require changing
how the configuration itself is loaded.

## load\_credentials

Override this function to change the way that [DBIx::Class::Schema::Config](https://metacpan.org/pod/DBIx::Class::Schema::Config)
loads credentials.  The function takes the class name, as well as a hashref.

If you take the route of having `->connect('DATABASE')` used as a key for
whatever configuration you are loading, _DATABASE_ would be
`$config->{dsn}`

    Some::Schema->connect(
        "SomeTarget",
        "Yuri",
        "Yawny",
        {
            TraceLevel => 1
        }
    );

Would result in the following data structure as $config in
`load_credentials($class, $config)`:

    {
        dsn             => "SomeTarget",
        user            => "Yuri",
        password        => "Yawny",
        TraceLevel      => 1,
    }

Currently, load\_credentials will NOT be called if the first argument to
`->connect()` looks like a valid DSN.  This is determined by match
the DSN with `/^dbi:/i`.

The function should return the same structure.  For instance:

    package My::Schema
    use warnings;
    use strict;
    use base 'DBIx::Class::Schema::Config';
    use LWP::Simple;
    use JSON

    # Load credentials from internal web server.
    sub load_credentials {
        my ( $class, $config ) = @_;

        return decode_json(
            get( "http://someserver.com/v1.0/database?key=somesecret&db=" .
                $config->{dsn}  ));
    }

    __PACKAGE__->load_classes;

# AUTHOR

Kaitlyn Parkhurst (SymKat) _<symkat@symkat.com>_ ( Blog: [http://symkat.com/](http://symkat.com/) )

# CONTRIBUTORS

- Matt S. Trout (mst) _<mst@shadowcat.co.uk>_
- Peter Rabbitson (ribasushi) _<ribasushi@cpan.org>_
- Christian Walde (Mihtaldu) _<walde.christian@googlemail.com>_
- Dagfinn Ilmari Mannsåker (ilmari) _<ilmari@ilmari.org>_
- Matthew Phillips (mattp)  _<mattp@cpan.org>_

# COPYRIGHT AND LICENSE

This library is free software and may be distributed under the same terms
as perl itself.

# AVAILABILITY

The latest version of this software is available at
[https://github.com/symkat/DBIx-Class-Schema-Config](https://github.com/symkat/DBIx-Class-Schema-Config)
