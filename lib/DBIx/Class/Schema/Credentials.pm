package DBIx::Class::Schema::Credentials;
use warnings;
use strict;
use base 'DBIx::Class::Schema';
use Config::Any;
use Data::Dumper;

sub connection {
    my ( $class, @info ) = @_;

    my $config = $class->_load_credentials( $class->_make_config( @info ) );
    
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

sub _load_credentials {
    my ( $class, $config ) = @_;

    return $config if $config->{dsn} =~ /^dbi:/i;

    # TODO This block is ugly, make it prettier.
    my $ConfigAny = Config::Any->load_stems( { stems => [$class->_config_paths], use_ext => 1 } );

    for my $cfile ( @$ConfigAny ) {
        my ($filename) = keys %$cfile;
        for my $database ( keys %{$cfile->{$filename}} ) {
            if ( lc($database) eq lc($config->{dsn}) ) {
                return $cfile->{$filename}->{$database};
            }
        }
    }
}

sub _config_paths {
    ( $ENV{HOME} . '/.dbic', './dbic', '/etc/dbic' );
}

1;

=head1 NAME

DBIx::Class::Schema::Credentials - Manage connection credentials for DBIx::Class::Schema

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
   
   use base 'DBIx::Class::Schema::Credentials';
   __PACKAGE__->load_namespaces;

   package My::Code;
   use warnings;
   use strict;
   use My::Schema;

   my $schema = My::Schema->connect('MY_DATABASE');

=head1 DESCRIPTION

DBIx::Class::Schema::Credentials is a subclass of DBIx::Class::Schema that allows the loading of credentials from a file.  The actual code itself would only need to know about the name of the database, this aims to make it simpler for operations teams to manage database credentials.

=head1 CONFIG FILES

This module will load the files in the following order if they exist:

    ./dbic.*
    ~/.dbic.*
    /etc/dbic.*

The files should have an extension that Config::Any recognizes, for example /etc/dbic.B<yaml>.

=head1 OVERRIDING

The API has been designed to be simple to override if you need more specific configuration loading.

=head2 _config_paths

Override this function to change the configuration paths that are searched, for example:

    package My::Credentials
    use warnings;
    use strict;
    use base 'DBIx::Class::Schema::Credentials';
    
   # Override _config_paths to search /var/config/dbic.* and /etc/myproject/project.*
    sub _config_paths {
        ( '/var/config/dbic', '/etc/myproject/project' );
    }

=head2 _load_credentials

Override this function to change the way that DBIx::Class::Schema::Credentials loads credentials, the functions takes the class name, as well as a hashref.

    if called as ->connect( "dbi:Pg:dbname=blog", "user", "password", { TraceLevel => 1 } )

    {
        dsn           => "dbi:Pg:dbname=blog",
        user          => "user",
        password => "password",
        options     => {
            TraceLevel => 1,
        },
    }

It if the responsibility of this function to allow passing through of normal ->connect calls, this is done by returning the current configuration is the dsn matches ^dbi:.

The function should return the same structure.  For instance:

    package My::Credentials
    use warnings;
    use strict;
    use base 'DBIx::Class::Schema::Credentials';
    use LWP::Simple;
    use JSON
    
    # Load credentials from internal web server.
    sub _load_credentials {
        my ( $class, $config ) = @_;
        
        return $config if $config->{dsn} =~ /^dbi:/i;

       return decode_json( 
           get( "http://someserver.com/v1.0/database?key=somesecret&db=" . $config->{dsn}  ));
    }

=head1 AUTHOR

SymKat I<E<lt>symkat@symkat.comE<gt>>

=head1 COPYRIGHT AND LICENSE

This is free software licensed under a I<BSD-Style> License.  Please see the 
LICENSE file included in this package for more detailed information.

=head1 AVAILABILITY

The latest version of this software is available through GitHub at
https://github.com/symkat/DBIx-Class-Schema-Credentials

=cut

