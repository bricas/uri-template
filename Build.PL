use strict;

use Module::Build;

my $build = Module::Build->new(
    module_name        => 'URI::Template',
    dist_author        => 'Brian Cassidy <brian.cassidy@nald.ca>',
    license            => 'perl',
    create_readme      => 1,
    create_makefile_pl => 'traditional',
    requires           => {
        'URI' => 0,
    },
    build_requres      => {
        'Test::More' => 0,
    }
);

$build->create_build_script;
