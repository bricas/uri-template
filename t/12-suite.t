use strict;
use warnings;

use Test::More;

BEGIN {
    eval "use JSON ();";
    plan skip_all => "JSON required" if $@;
    plan( 'no_plan' );
    use_ok( 'URI::Template' );
}

my @files = glob( 't/cases/*.json' );

for my $file ( @files ) {
    open( my $json, $file );
    my $data = do { local $/; <$json> };
    close( $json );

    eval { JSON->VERSION( 2 ) };
    my $suite     = $@ ? JSON::jsonToObj( $data ) : JSON::from_json( $data );

    for my $name ( sort keys %$suite ) {
        my $info  = $suite->{ $name };
        my $vars  = $info->{ variables };
        my $cases = $info->{ testcases };

        diag( sprintf( '%s [level %d]', $name, ( $info->{ level } || 4 ) ) );

        for my $case ( @$cases ) {
            my( $input, $expect ) = @$case;
#            my $template = URI::Template->new( $input );
#            my $result   = $template->process( $variables );
#            is( $result, $expected, $template );
        }

    }
}

