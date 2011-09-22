package DBIx::Class::Schema::Config;
use 5.005;
use warnings;
use strict;
use base 'DBIx::Class::Schema';

our $VERSION = '0.001002'; # 0.1.2
$VERSION = eval $VERSION;

sub connection {
    my ( $class, @info ) = @_;

    my $config = $class->load_credentials(
        $class->_make_config( @info )
    );

    return $class->next::method( $config );
}

# Normalize arrays into hashes, so we have only one form
# to work with later.
sub _make_config {
    my ( $class, $dsn, $user, $pass, $dbi_attr, $extra_attr ) = @_;
    return $dsn if ref $dsn eq 'HASH';

    my %connection = ( dsn => $dsn, user => $user, password => $pass );

    return { %connection, %{$dbi_attr || {} }, %{ $extra_attr || {} } }; 
}

sub load_credentials {
    my ( $class, $connect_args ) = @_;
    require Config::Any;

    return $connect_args if $connect_args->{dsn} =~ /^dbi:/i; 

    my $ConfigAny = Config::Any
        ->load_stems( { stems => $class->config_paths, use_ext => 1 } );

    for my $cfile ( @$ConfigAny ) {
        for my $filename ( keys %$cfile ) {
            for my $database ( keys %{$cfile->{$filename}} ) {
                if ( $database eq $connect_args->{dsn} ) {
                    my $loaded_credentials = $cfile->{$filename}->{$database};
                    return $class->filter_loaded_credentials(
                        $loaded_credentials,$connect_args
                    );
                }
            }
        }
    }
}

sub filter_loaded_credentials { $_[1] };

__PACKAGE__->mk_classaccessor('config_paths'); 
__PACKAGE__->config_paths([('./dbic', $ENV{HOME} . '/.dbic', '/etc/dbic')]);

1;
=head1 NAME

DBIx::Class::Schema::Config - 
Manage connection credentials for DBIx::Class::Schema in a file.

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

=over 4

=item * ./dbic.*

=item * ~/.dbic.*

=item * /etc/dbic.*

=back

The files should have an extension that L<Config::Any> recognizes, 
for example /etc/dbic.B<yaml>.

NOTE:  The first available credential will be used.  Therefore I<DATABASE> 
in ~/.dbic.yaml will only be looked at if it was not found in ./dbic.yaml.  
If there are duplicates in one file (such that DATABASE is listed twice in 
~/.dbic.yaml) the first configuration will be used.

=head1 CHANGE CONFIG PATH

Use C<__PACKAGE__-E<gt>config_paths([( '/file/stub', '/var/www/etc/dbic')]);> 
to change the paths that are searched.  For example:

    package My::Schema
    use warnings;
    use strict;

    use base 'DBIx::Class::Schema::Config';
    __PACKAGE__->config_paths([( '/var/www/secret/dbic', '/opt/database' )]);

The above code would have I</var/www/secret/dbic.*> and I</opt/database.*> 
searched.  As above, the first credentials found would be used.

=head1 OVERRIDING

The API has been designed to be simple to override if you have additional 
needs in loading DBIC configurations.

=head2 on_credential_load

Give a code reference to this accessor if you want to change
the loaded credentials before they are passed to DBIC.  Useful
use-cases for this include decrypting encrypted passwords, or
making programatic changes to the configuration file.

    __PACKAGE__->on_credential_load( sub { my ( $orig, $new ) = @_; } );

C<$orig> is the structure originally passed on C<-E<gt>connect()> after it has
been turned into a hash.  For instance C<-E<gt>connect('DATABASE', 'USERNAME')>
will result in C<$orig-E<gt>{dsn}> eq B<DATABASE> and C<$orig-E<gt>{user}> eq 
B<USERNAME>.

C<$new> is the structure after it has been loaded from the configuration file.
In this case, C<$new-E<gt>{user}> eq B<WalterWhite> and C<$new-E<gt>{dsn}> eq 
B<DBI:mysql:database=students;host=%s;port=3306>.

For instance, if you want to use hostnames when you make the
initial connection to DBIC and are using the configuration primarily
for usernames, passwords and other configuration data, you can create
a config like the following:

    DATABASE:
        dsn: "DBI:mysql:database=students;host=%s;port=3306"
        user: "WalterWhite"
        password: "relykS"

In your Schema class you could include the following:

    package My::Schema
    use warnings;
    use strict;
    use base 'DBIx::Class::Schema::Config';
    
    __PACKAGE__->on_credential_load(
        sub {
            my ( $orig, $new ) = @_;
            if ( $new->{dsn} =~ /\%s/ ) {
                $new->{dsn} = sprintf($new->{dsn}, $orig->{user});
            }
            return $new;
        }
    );

    __PACKAGE__->load_classes;
    1;

See L</load_credentials> for more complex changes that require changing
how the configuration itself is loaded.

=head2 load_credentials

Override this function to change the way that L<DBIx::Class::Schema::Config>
loads credentials, the functions takes the class name, as well as a hashref.

If you take the route of having C<-E<gt>connect('DATABASE')> used as a key for 
whatever configuration you are loading, I<DATABASE> would be 
C<$config-E<gt>{dsn}>

    Some::Schema->connect( 
        "dbi:Pg:dbname=blog", 
        "user", 
        "password", 
        { 
            TraceLevel => 1 
        } 
    );

Would result in the following data structure as $config in 
C<load_credentials($class, $config)>:

    {
        dsn             => "dbi:Pg:dbname=blog",
        user            => "user",
        password        => "password",
        TraceLevel      => 1,
    }

It if the responsibility of this function to allow passing through of normal 
C<-E<gt>connect> calls, this is done by returning the current configuration 
if the dsn matches ^dbi:.

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

The latest version of this software is available at GitHub 
https://github.com/symkat/DBIx-Class-Schema-Config

=cut
