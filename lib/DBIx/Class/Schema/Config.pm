package DBIx::Class::Schema::Config;
use 5.005;
use warnings;
use strict;
use base 'DBIx::Class::Schema';
use File::HomeDir;

our $VERSION = '0.001009'; # 0.1.9
$VERSION = eval $VERSION;

sub connection {
    my ( $class, @info ) = @_;

    my $config = $class->_make_config(@info);

    # Take responsibility for passing through normal-looking
    # credentials.
    $config = $class->load_credentials($config)
        unless $config->{dsn} =~ /dbi:/i;

    return $class->next::method( $config );
}

# Normalize arguments into a single hash.  If we get a single hashref,
# return it.
# Check if $user and $pass are hashes to support things like
# ->connect( 'CONFIG_FILE', { hostname => 'db.foo.com' } );

sub _make_config {
    my ( $class, $dsn, $user, $pass, $dbi_attr, $extra_attr ) = @_;
    return $dsn if ref $dsn eq 'HASH';

    return { 
        dsn => $dsn, 
        %{ref $user eq 'HASH' ? $user : { user => $user }},
        %{ref $pass eq 'HASH' ? $pass : { password => $pass }},
        %{$dbi_attr || {} }, 
        %{ $extra_attr || {} } 
    }; 
}

sub load_credentials {
    my ( $class, $connect_args ) = @_;
    require Config::Any; # Only loaded if we need to load credentials.

    # While ->connect is responsible for returning normal-looking
    # credential information, we do it here as well so that it can be
    # independently unit tested.
    return $connect_args if $connect_args->{dsn} =~ /^dbi:/i; 

    # If we have ->config_files, we'll use those and load_files
    # instead of the default load_stems.
    my %cf_opts = ( use_ext => 1 );
    my $ConfigAny = @{$class->config_files}
        ? Config::Any->load_files({ files => $class->config_files, %cf_opts })
        : Config::Any->load_stems({ stems => $class->config_paths, %cf_opts });

    return $class->filter_loaded_credentials(
        $class->_find_credentials( $connect_args, $ConfigAny ),
        $connect_args
    );

}

# This will look through the data structure returned by Config::Any
# and return the first instance of the database credentials it can
# find.
sub _find_credentials {
    my ( $class, $connect_args, $ConfigAny ) = @_;
    
    for my $cfile ( @$ConfigAny ) {
        for my $filename ( keys %$cfile ) {
            for my $database ( keys %{$cfile->{$filename}} ) {
                if ( $database eq $connect_args->{dsn} ) {
                    return $cfile->{$filename}->{$database};
                }
            }
        }
    }
}

sub get_env_vars {
    return $ENV{DBIX_CONFIG_DIR} . "/dbic" if exists $ENV{DBIX_CONFIG_DIR};
    return ();
}

# Intended to be sub-classed, we'll just return the
# credentials we used in the first place.
sub filter_loaded_credentials { $_[1] };

__PACKAGE__->mk_classaccessor('config_paths'); 
__PACKAGE__->mk_classaccessor('config_files'); 
__PACKAGE__->config_paths([( get_env_vars(), './dbic', File::HomeDir->my_home . '/.dbic', '/etc/dbic')]);
__PACKAGE__->config_files([  ] );

1;

=head1 NAME

DBIx::Class::Schema::Config - Credential Management for DBIx::Class 

=head1 DESCRIPTION

DBIx::Class::Schema::Config is a subclass of DBIx::Class::Schema 
that allows the loading of credentials from a file.  The actual code 
itself would only need to know about the name used in the configuration
file. This aims to make it simpler for operations teams to manage database
credentials.  

A simple tutorial that compliments this documentation and explains converting 
an existing DBIx::Class Schema to usingthis software to manage credentials can 
be found at L<http://www.symkat.com/credential-management-in-dbix-class>

=head1 SYNOPSIS

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

=head1 CONFIG FILES

This module will load the files in the following order if they exist:

=over 4

=item * C<$ENV{DBIX_CONFIG_DIR}> . '/dbic', 

C<$ENV{DBIX_CONFIG_DIR}> can be configured at run-time, for instance:

    DBIX_CONFIG_DIR="/var/local/" ./my_program.pl

=item * ./dbic.*

=item * ~/.dbic.*

=item * /etc/dbic.*

=back

The files should have an extension that L<Config::Any> recognizes, 
for example /etc/dbic.B<yaml>.

NOTE:  The first available credential will be used.  Therefore I<DATABASE> 
in ~/.dbic.yaml will only be looked at if it was not found in ./dbic.yaml.  
If there are duplicates in one file (such that DATABASE is listed twice in 
~/.dbic.yaml,) the first configuration will be used.

=head1 CHANGE CONFIG PATH

Use C<__PACKAGE__-E<gt>config_paths([( '/file/stub', '/var/www/etc/dbic')]);> 
to change the paths that are searched.  For example:

    package My::Schema
    use warnings;
    use strict;

    use base 'DBIx::Class::Schema::Config';
    __PACKAGE__->config_paths([( '/var/www/secret/dbic', '/opt/database' )]);

The above code would have I</var/www/secret/dbic.*> and I</opt/database.*> 
searched, in that order.  As above, the first credentials found would be used.  
This will replace the files origionally searched for, not add to them.

=head1 USE SPECIFIC CONFIG FILES

If you would rather explicitly state the configuration files you
want loaded, you can use the class accessor C<config_files>
instead.

    package My::Schema
    use warnings;
    use strict;

    use base 'DBIx::Class::Schema::Config';
    __PACKAGE__->config_files([( '/var/www/secret/dbic.yaml', '/opt/database.yaml' )]);

This will check the files, C</var/www/secret/dbic.yaml>, 
and C</opt/database.yaml> in the same way as C<config_paths>, 
however it will only check the specific files, instead of checking 
for each extension that L<Config::Any> supports.  You MUST use the 
extension that corresponds to the file type you are loading.  
See L<Config::Any> for information on supported file types and 
extension mapping.

=head1 OVERRIDING

The API has been designed to be simple to override if you have additional 
needs in loading DBIC configurations.

=head2 filter_loaded_credentials

Override this function if you want to change the loaded credentials before
they are passed to DBIC.  This is useful for use-cases that include decrypting
encrypted passwords or making progamatic changes to the configuration before
using it.

    sub filter_loaded_credentials {
        my ( $class, $loaded_credentials, $connect_args ) = @_;
        ...
        return $loaded_credentials;
    }

C<$loaded_credentials> is the structure after it has been loaded from the 
configuration file.  In this case, C<$loaded_credentials-E<gt>{user}> eq 
B<WalterWhite> and C<$loaded_credentials-E<gt>{dsn}> eq 
B<DBI:mysql:database=students;host=%s;port=3306>.

C<$connect_args> is the structure originally passed on C<-E<gt>connect()> 
after it has been turned into a hash.  For instance, 
C<-E<gt>connect('DATABASE', 'USERNAME')> will result in 
C<$connect_args-E<gt>{dsn}> eq B<DATABASE> and C<$connect_args-E<gt>{user}> 
eq B<USERNAME>.

Additional parameters can be added by appending a hashref,
to the connection call, as an example, C<-E<gt>connect( 'CONFIG', 
{ hostname =E<gt> "db.foo.com" } );> will give C<$connect_args> a
structure like C<{ dsn =E<gt> 'CONFIG', hostname =E<gt> "db.foo.com" }>.

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
C<$Schema-E<gt>connect('DATABASE', { hostname => 'my.hostname.com' });>

See L</load_credentials> for more complex changes that require changing
how the configuration itself is loaded.

=head2 load_credentials

Override this function to change the way that L<DBIx::Class::Schema::Config>
loads credentials.  The function takes the class name, as well as a hashref.

If you take the route of having C<-E<gt>connect('DATABASE')> used as a key for 
whatever configuration you are loading, I<DATABASE> would be 
C<$config-E<gt>{dsn}>

    Some::Schema->connect( 
        "SomeTarget", 
        "Yuri", 
        "Yawny", 
        { 
            TraceLevel => 1 
        } 
    );

Would result in the following data structure as $config in 
C<load_credentials($class, $config)>:

    {
        dsn             => "SomeTarget",
        user            => "Yuri",
        password        => "Yawny",
        TraceLevel      => 1,
    }

Currently, load_credentials will NOT be called if the first argument to
C<-E<gt>connect()> looks like a valid DSN.  This is determined by match
the DSN with C</^dbi:/i>.

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

=head1 AUTHOR

Kaitlyn Parkhurst (SymKat) I<E<lt>symkat@symkat.comE<gt>> ( Blog: L<http://symkat.com/> )

=head1 CONTRIBUTORS

=over 4

=item * Matt S. Trout (mst) I<E<lt>mst@shadowcat.co.ukE<gt>> 

=item * Peter Rabbitson (ribasushi) I<E<li>ribasushi@cpan.orgE<GT>>

=item * Christian Walde I<E<lt>walde.christian@googlemail.comE<gt>>

=item * Dagfinn Ilmari MannsÃ¥ker I<E<lt>ilmari@photobox.com<gt>>

=back

=head1 COPYRIGHT AND LICENSE

This library is free software and may be distributed under the same terms 
as perl itself.

=head1 AVAILABILITY

The latest version of this software is available at
L<https://github.com/symkat/DBIx-Class-Schema-Config>

=cut
