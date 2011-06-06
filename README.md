# NAME

DBIx::Class::Schema::Config - Manage connection credentials for DBIx::Class::Schema in a file.

# SYNOPSIS

    /etc/dbic.yaml
    MY_DATABASE:
        dsn: "rbi:Pg:host=localhost;database=blog"
        user: "TheDoctor"
        password: "dnoPydoleM"
        options:
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

# DESCRIPTION

DBIx::Class::Schema::Config is a subclass of DBIx::Class::Schema 
that allows the loading of credentials from a file.  The actual code 
itself would only need to know about the name of the database, this 
aims to make it simpler for operations teams to manage database credentials.

# CONFIG FILES

This module will load the files in the following order if they exist:

* ./dbic.*
* ~/.dbic.*
* /etc/dbic.*

The files should have an extension that Config::Any recognizes, for example /etc/dbic.__yaml__.

NOTE:  The first available credential will be used.  Therefore DATABASE in ~/.dbic.yaml 
will only be looked at if it was not found in ./dbic.yaml.  If there are duplicates in
one file (such that DATABASE is listed twice in ~/.dbic.yaml) the first configuration 
will be used.

# OVERRIDING

The API has been designed to be simple to override if you need more specific configuration loading.

## config_paths

Override this function to change the configuration paths that are searched, for example:

    package My::Credentials
    use warnings;
    use strict;
    use base 'DBIx::Class::Schema::Credentials';
    

    # Override _config_paths to search 
    # /var/config/dbic.* and /etc/myproject/project.*
    sub config_paths {
        ( '/var/config/dbic', '/etc/myproject/project' );
    }

## load_credentials

Override this function to change the way that DBIx::Class::Schema::Credentials 
loads credentials, the functions takes the class name, as well as a hashref.

If you take the route of having `->connect('DATABASE')` used as a key for whatever
configuration you are loading, 'DATABASE' would be `$config->{dsn}`

    Some::Schema->connect( "dbi:Pg:dbname=blog", "user", "password", { TraceLevel => 1 } )

Would result in the following data structure as $config in `load_credentials($class, $config)`:

    {
        dsn      => "dbi:Pg:dbname=blog",
        user     => "user",
        password => "password",
        options  => {
            TraceLevel => 1,
        },
    }

It if the responsibility of this function to allow passing through of normal 
`->connect` calls, this is done by returning the current configuration if the 
dsn matches ^dbi:.

The function should return the same structure.  For instance:

    package My::Credentials
    use warnings;
    use strict;
    use base 'DBIx::Class::Schema::Credentials';
    use LWP::Simple;
    use JSON


    # Load credentials from internal web server.
    sub load_credentials {
        my ( $class, $config ) = @_;

        return $config if $config->{dsn} =~ /^dbi:/i;

        return decode_json( 
            get( "http://someserver.com/v1.0/database?key=somesecret&db=" . 
                $config->{dsn}  ));
    }

# AUTHOR

SymKat _<symkat@symkat.com>_

# COPYRIGHT AND LICENSE

This is free software licensed under a _BSD-Style_ License.  Please see the 
LICENSE file included in this package for more detailed information.

# AVAILABILITY

The latest version of this software is available through GitHub at
https://github.com/symkat/DBIx-Class-Schema-Config
