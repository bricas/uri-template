use strict;
use warnings;

use Test::More tests => 11;

use_ok( 'URI::Template' );

{
    my $text     = 'http://foo.com/{bar}/{baz}?q=%7B';
    my $template = URI::Template->new( $text );
    isa_ok( $template, 'URI::Template' );
    is_deeply( [ $template->variables ], [ qw( bar baz ) ], 'variables()' );
    is( "$template", $text, 'as_string()' );

    my $result = $template->process( bar => 'x', baz => 'y' );
    is( $result, 'http://foo.com/x/y?q=%7B', 'fill()' );
    isa_ok( $result, 'URI', 'return value from fill() isa URI' );
}

{
    my $template = URI::Template->new( 'http://foo.com/{z(}/' );
    my $result = $template->process( 'z(' => 'x' );
    is( $result, 'http://foo.com/x/', 'potential regex issue escaped' );
}

{
    my $template = URI::Template->new( 'http://foo.com/{z}/' );
    {
        my $result = $template->process( 'z' => '{x}' );
        is( $result, 'http://foo.com/%7Bx%7D/', 'values are uri escaped' );
    }
    {
        my $result = $template->process( );
        is( $result, 'http://foo.com//', 'no value sent' );
    }
}

{
    my $template = URI::Template->new( 'http://foo.com/{z}/{z}/' );
    is_deeply( [ $template->variables ], [ 'z' ], 'unique vars' );
    my $result = $template->process( 'z' => 'x' );
    is( $result, 'http://foo.com/x/x/', 'multiple replaces' );
}

