#!/usr/bin/perl
use warnings;
use strict;
use Test::More;
use DBIx::Class::Schema::Config;

my $tests = [
    {
        put => 
            {
                dsn => 'dbi:mysql:somedb',
                user => 'username',
                password => 'password',
            },
        get => 
            {
                dsn      => 'dbi:mysql:somedb',
                user     => 'username',
                password     => 'password',
                options  => {},
            },
        title => "Hashref connections work.",
    },
    {
        put => [ 'dbi:mysql:somedb', 'username', 'password' ],
        get => 
            {
                dsn      => 'dbi:mysql:somedb',
                user     => 'username',
                password => 'password',
                options  => undef,
            },
        title => "Array connections work.",
    },
    {
        put => [ 'DATABASE' ],
        get => { dsn => 'DATABASE', user => undef, password => undef, options => undef },
        title => "DSN gets the first element name.",
    },
    {
        put => [ 'dbi:mysql:somedb', 'username', 'password', { PrintError => 1 } ],
        get => 
        {
            dsn      => 'dbi:mysql:somedb',
            user     => 'username',
            password => 'password',
            options  => { PrintError => 1 },
        },
        title => "Normal option hashes pass through.",
    },

];


for my $test ( @$tests ) {
    is_deeply( 
        DBIx::Class::Schema::Config->_make_config( 
            ref $test->{put} eq 'ARRAY' ? @{$test->{put}} : $test->{put}
        ), $test->{get}, $test->{title} );
}

done_testing;
