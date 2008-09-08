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
    my $data = do { local $/; <$json> };
    close( $json );

    eval { JSON->VERSION( 2 ) };
    my $suite     = $@ ? JSON::jsonToObj( $data ) : JSON::from_json( $data );
    my $variables = $suite->{variables};

    my $count = 0;
    for my $test (@{ $suite->{tests} }) {
        my $template = URI::Template->new( $test->{template} );
        my $result   = $template->process( $variables );
        $count++;
        is( $result, $test->{expected}, "${file} test ${count}" );
    }
}

