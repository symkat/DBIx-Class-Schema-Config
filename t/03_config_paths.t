#!/usr/bin/perl
use warnings;
use strict;
use Test::More;
use DBIx::Class::Schema::Credentials;


is_deeply(
    [DBIx::Class::Schema::Credentials->config_paths],
    [ './dbic', $ENV{HOME} . "/.dbic", "/etc/dbic"  ],
    "_config_paths looks sane.");

done_testing;
