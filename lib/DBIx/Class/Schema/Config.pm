package DBIx::Class::Schema::Config;
use 5.005;
use warnings;
use strict;
use base 'DBIx::Class::Schema';
use Config::Any;
use Data::Dumper;

our $VERSION = '0.001000'; # 0.1.0
$VERSION = eval $VERSION;


sub connection {
    my ( $class, @info ) = @_;

    my $config = $class->load_credentials( $class->_make_config( @info ) );
    
    return $class->SUPER::connection(
        $config->{dsn},
        $config->{user},
        $config->{password},
        $config->{options},
    );
}

sub _make_config {
    my ( $class, $dsn, $user, $pass, $options ) = @_;
    
    if ( ref $dsn eq 'HASH' ) {
        # Handle the special case of Test::DBIx::Class
        my $config = { };
        $config->{user}         = delete $dsn->{user};
        $config->{password}     = delete $dsn->{password};
        $config->{dsn}          = delete $dsn->{dsn};
        $config->{options}      = $dsn;
        return $config;
    }
    return { 
        dsn      => $dsn, 
        user     => $user, 
        password => $pass,
        options  => $options,
    };
}

sub load_credentials {
    my ( $class, $config ) = @_;

    return $config if $config->{dsn} =~ /^dbi:/i;

    # TODO This block is ugly, make it prettier.
    my $ConfigAny = Config::Any->load_stems( { stems => $class->config_paths, use_ext => 1 } );

    for my $cfile ( @$ConfigAny ) {
        my ($filename) = keys %$cfile;
        for my $database ( keys %{$cfile->{$filename}} ) {
            if ( $database eq $config->{dsn} ) {
                return $cfile->{$filename}->{$database};
            }
        }
    }
}

__PACKAGE__->mk_classaccessor('config_paths'); 
__PACKAGE__->config_paths([ ('./dbic', $ENV{HOME} . '/.dbic', '/etc/dbic') ]);

1;
=head1 NAME

DBIx::Class::Schema::Config - Manage connection credentials for DBIx::Class::Schema in a file.

=head1 SYNOPSIS

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

=head1 DESCRIPTION

DBIx::Class::Schema::Config is a subclass of DBIx::Class::Schema 
that allows the loading of credentials from a file.  The actual code 
itself would only need to know about the name of the database, this 
aims to make it simpler for operations teams to manage database credentials.

=head1 CONFIG FILES

This module will load the files in the following order if they exist:

* ./dbic.*
* ~/.dbic.*
* /etc/dbic.*

The files should have an extension that Config::Any recognizes, for example /etc/dbic.B<yaml>.

NOTE:  The first available credential will be used.  Therefore DATABASE in ~/.dbic.yaml 
will only be looked at if it was not found in ./dbic.yaml.  If there are duplicates in
one file (such that DATABASE is listed twice in ~/.dbic.yaml) the first configuration 
will be used.

=head1 CHANGE CONFIG PATH

Use B<__PACKAGE__->config_paths([( '/file/stub', '/var/www/etc/dbic')]);> to change the paths
that are searched.  For example:

    package My::Schema
    use warnings;
    use strict;

    use base 'DBIx::Class::Schema::Config';
    __PACKAGE__->config_paths( [ ( '/var/www/secret/dbic', '/opt/database' ) ] );

The above code would have B</var/www/secret/dbic.*> and B</opt/database.*> searched.  As
above, the first credentials found would be used.

=head1 OVERRIDING

The API has been designed to be simple to override if you need more specific configuration loading.

=head2 load_credentials

Override this function to change the way that DBIx::Class::Schema::Credentials 
loads credentials, the functions takes the class name, as well as a hashref.

If you take the route of having B<->connect('DATABASE')> used as a key for whatever
configuration you are loading, 'DATABASE' would be B<$config->{dsn}>

    Some::Schema->connect( "dbi:Pg:dbname=blog", "user", "password", { TraceLevel => 1 } )

Would result in the following data structure as $config in B<load_credentials($class, $config)>:

    {
        dsn      => "dbi:Pg:dbname=blog",
        user     => "user",
        password => "password",
        options  => {
            TraceLevel => 1,
        },
    }

It if the responsibility of this function to allow passing through of normal 
B<->connect> calls, this is done by returning the current configuration if the 
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

=head1 AUTHOR

SymKat I<E<lt>symkat@symkat.comE<gt>>

=head1 COPYRIGHT AND LICENSE

This is free software licensed under a I<BSD-Style> License.  Please see the 
LICENSE file included in this package for more detailed information.

=head1 AVAILABILITY

The latest version of this software is available through GitHub at
https://github.com/symkat/DBIx-Class-Schema-Config
=cut
