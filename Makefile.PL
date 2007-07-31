use inc::Module::Install 0.65;

name 'URI-Template';
all_from 'lib/URI/Template.pm';

requires 'URI';
requires 'Test::More';

auto_install;
WriteAll;
