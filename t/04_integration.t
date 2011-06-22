#!/usr/bin/perl
use warnings;
use strict;
use Test::More;
use DBIx::Class::Schema::Config::Test;

ok my $Schema = DBIx::Class::Schema::Config::Test->connect('TEST'),
    "Can connect to the Test Schema.";

ok $Schema->storage->dbh->do( "CREATE TABLE hash ( key text, value text )" ),
    "Can create table against the raw dbh.";

ok $Schema->resultset('Hash')->create( { key => "Dr", value => "Spaceman" } ),
    "Can write to the Test Schema.";

is $Schema->resultset('Hash')->find( { key => 'Dr' } )->value, 'Spaceman',
    "Can read from the Test Schema.";

done_testing;
