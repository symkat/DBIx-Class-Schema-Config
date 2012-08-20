use inc::Module::Install;
  
# Define metadata
name           'DBIx-Class-Schema-Config';
all_from       'lib/DBIx/Class/Schema/Config.pm';
license         'perl';

# Specific dependencies
requires       'DBIx::Class'            => '0.08100';
requires       'Config::Any'            => '0.23';
requires       'File::HomeDir'          => '0';

test_requires  'Test::More'             => '0.42';
test_requires  'DBD::SQLite'            => '0';
test_requires  'Test::MockObject'       => '1.09';
test_requires  'Config::Any'            => '0.23';

WriteAll;
