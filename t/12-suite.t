use strict;
use warnings;

use Test::More;

BEGIN {
    eval "use JSON ();";
    plan skip_all => "JSON required" if $@;
    plan( 'no_plan' );
    use_ok( 'URI::Template' );
}

my @files = glob( 't/data/*.json' );

for my $file ( @files ) {
    open( my $json, $file );
    my $suite = JSON::jsonToObj( do { local $/; <$json> } );
    close( $json );

    my %variables = %{ $suite->{ variables } };

    my $count = 0;
    for my $test ( @{ $suite->{ tests } } ) {
        my $template = URI::Template->new( $test->{ template } );
        my $result = $template->process( %variables );
        $count++;
        is( $result, $test->{ expected }, "${file}#${count}" );
    }
}


