use strict;
use warnings;

use Test::More tests => 9;

use_ok( 'URI::Template' );

{
    my $text     = 'http://foo.com/{arg2}/{arg1}';
    my $template = URI::Template->new( $text );
    isa_ok( $template, 'URI::Template' );
    is_deeply(
        [ $template->all_variables ],
        [ qw( arg2 arg1 ) ],
        'all_variables()'
    );

    {
        my $result = $template->process( [ qw( x y ) ] );
        is( $result, 'http://foo.com/x/y', 'process(\@args)' );
        isa_ok( $result, 'URI', 'return value from process() isa URI' );
    }

    {
        my $result = $template->process_to_string( [ qw( x y ) ] );
        is( $result, 'http://foo.com/x/y', 'process_to_string(\@args)' );
        ok( !ref $result, 'result is not a ref' );
    }

    # test for 0 as value
    {
        my $result = $template->process_to_string( [ qw( 0 0 ) ] );
        is( $result, 'http://foo.com/0/0', 'process w/ 0' );
    }

    # test with no values
    {
        my $result = $template->process_to_string( [] );
        is( $result, 'http://foo.com//', 'process w/ no values' );
    }
}

