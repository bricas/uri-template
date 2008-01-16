use inc::Module::Install 0.68;

name 'URI-Template';
all_from 'lib/URI/Template.pm';

requires 'URI';

test_requires 'Test::More';

auto_install;
WriteAll;
