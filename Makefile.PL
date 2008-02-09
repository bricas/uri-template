use inc::Module::Install 0.68;

if ( -e 'MANIFEST.SKIP' ) {
    system( 'pod2text lib/URI/Template.pm > README' );
}

perl_version '5.006';

name 'URI-Template';
all_from 'lib/URI/Template.pm';

requires 'URI';

test_requires 'Test::More';

auto_install;
WriteAll;
