use inc::Module::Install;
  
# Define metadata
name           'DBIx-Class-Schema-Config';
all_from       'lib/DBIx/Class/Schema/Config.pm';
license         'bsd';

# Specific dependencies
requires       'DBIx::Class'    => '0.08100';
requires       'DBI'            => '1.609';

test_requires  'Test::More'     => '0.42';

WriteAll;
